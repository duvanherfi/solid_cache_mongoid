# Solid Cache for Mongoid

[![Gem Version](https://img.shields.io/gem/v/solid_cache_mongoid?style=flat-square)](https://rubygems.org/gems/solid_cache_mongoid)
[![Downloads](https://img.shields.io/gem/dt/solid_cache_mongoid?style=flat-square)](https://rubygems.org/gems/solid_cache_mongoid)
[![License](https://img.shields.io/github/license/duvanherfi/solid_cache_mongoid?style=flat-square)](MIT-LICENSE)

A database-backed `ActiveSupport::Cache::Store` for Rails applications that run
on **MongoDB**.

Rails 8 ships [Solid Cache](https://github.com/rails/solid_cache), which trades
RAM for disk: modern SSDs are fast enough that a large cache on disk beats a
small cache in memory for most workloads. But Solid Cache is built on Active
Record. An application backed by Mongoid cannot use it, and gets pushed onto
Redis or Memcached for caching alone — one more service to run, pay for, and be
paged about.

This is Solid Cache rewritten on Mongoid, so those applications can cache
against the database they already have.

## Installation

```ruby
# Gemfile
gem "solid_cache_mongoid"
```

```sh
bundle install
bin/rails generate solid_cache_mongoid:install
```

The generator writes `config/cache.yml` and points `config.cache_store` at
`:solid_cache_mongoid_store` in development, test and production.

There is no migration to run. The collection is created on first write and the
indexes are declared on the model — a unique index on `key_hash` for lookups,
plus `byte_size` and a compound `key_hash + byte_size` used by size estimation.

Requires Rails >= 7.2 (< 8.1) and Mongoid >= 9.

## Configuration

The cache always lives in its own Mongo database — `solid_cache_mongoid` unless
you name another one — in a `solid_cache_entries` collection. It never shares
the application's database, so cache traffic and application traffic can be
pointed at different clients, and dropping the cache can never touch business
data.

`config/cache.yml`:

```yaml
default: &default
  database: solid_cache_mongoid
  store_options:
    max_age: <%= 60.days.to_i %>
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>

development:
  <<: *default

production:
  <<: *default
```

Top-level options:

| Option | Default | What it does |
|---|---|---|
| `database` | `solid_cache_mongoid` | Mongo database holding the cache. |
| `collection` | `solid_cache_entries` | Collection name. |
| `client` | — | Mongoid client to use, if not the default one. |
| `encrypt` | `false` | Encrypt keys and values at rest. |
| `encryption_context_properties` | `{ deterministic: false }` | Passed to Mongoid encryption. |
| `size_estimate_samples` | `10_000` | Documents sampled when estimating cache size. |

`store_options` are handed to the cache store itself: `max_age`, `max_size`,
`max_entries`, `namespace`, `expiry_batch_size`, `expiry_method`,
`expiry_queue`.

### Encryption at rest

Setting `encrypt: true` turns on Mongoid field encryption for `key` and
`value`, keyed from `SOLID_CACHE_KEY_ENCRYPT` or, absent that, the
application's `secret_key_base`. Encryption is non-deterministic by default:
the same value encrypts differently each time, so an attacker reading the
collection cannot tell which entries hold the same content.

## How expiry works

Expiry is not a cron job. Writes trigger it probabilistically, so the cache
trims itself in proportion to how hard it is being used and an idle
application does no work at all.

Each pass asks for three times as many candidates as it intends to delete and
then randomly samples down to the real count. That is deliberate: with several
workers expiring concurrently, taking the first N of an ordered list means
every worker fights over the same documents. Oversampling and choosing at
random keeps their working sets mostly disjoint.

Candidates are ordered by `_id`. A BSON `ObjectId` begins with a 4-byte
timestamp, so `_id` order is creation order — the same property upstream gets
from an autoincrementing primary key — which means age-based expiry needs no
index on `created_at`.

## What is different from upstream Solid Cache

The port is not a search-and-replace of `ApplicationRecord` for a Mongoid
model. The parts of Solid Cache that lean on SQL semantics had to be rebuilt.

**Locking.** Upstream uses Active Record transactions and database advisory
locks so concurrent expiry passes do not collide. MongoDB has no advisory
locks, so this uses [`mongoid-locker`](https://github.com/mongoid/mongoid-locker),
which takes a document-level lock through `locking_name` and `locked_at`
fields on the entry itself.

**Binary storage.** Keys and values are `BSON::Binary`, not SQL `BLOB`
columns, and are unwrapped on read. Serialized cache values are arbitrary
bytes; letting BSON infer a type would corrupt them.

**Key hashing.** Lookups match on a 64-bit hash of the key, clamped to
`-(2**63)..(2**63 - 1)` so it fits BSON's `int64`. The index stays small and
fixed-width regardless of how long the application's cache keys are. The hash
is also uniformly distributed, which is what makes the sampling below work.

**Row counting.** Upstream estimates how many rows the table holds by
subtracting the smallest primary key from the largest — cheap and accurate
with an autoincrementing integer. ObjectIds are not subtractable that way, so
this port counts documents instead.

**Query cache.** `without_query_cache` maps onto `Mongo::QueryCache.uncached`
rather than Active Record's connection-level query cache.

**Sharding.** Upstream can spread the cache across several databases through
`connects_to`. This port runs against a single unmanaged connection.
Applications that need to shard should shard in MongoDB.

## Size estimation

Storing a `byte_size` per document makes the total cache size estimable
without scanning the collection:

1. Take the N largest documents by `byte_size` — there is an index for it — and
   sum them exactly. These are the outliers that would otherwise skew any
   sample.
2. Use the smallest of those as a cutoff, and sample the rest through a random
   window of the `key_hash` range. Because `key_hash` is uniformly distributed
   and indexed together with `byte_size`, the sum comes straight out of the
   index.
3. Scale the sampled sum back up by the sampling fraction and add the outliers.

The result is an estimate whose cost does not grow with the size of the cache.

## Batching

`read_multi` and `write_multi` slice their input into batches of 1000, so a
wide `fetch_multi` costs a handful of round trips instead of one per key.

## Credit

Original Solid Cache by [Donal McBreen](https://github.com/djmb) and 37signals.
Mongoid port by [Duvan Hernandez](https://github.com/duvanherfi). MIT licensed,
same as upstream.
