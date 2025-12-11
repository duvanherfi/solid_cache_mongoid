# Solid Cache

Solid Cache is a database-backed Active Support cache store that lets you keep a much larger cache than is typically possible with traditional memory-only Redis or Memcached stores. This is thanks to the speed of modern SSD drives, which make the access-time penalty of using disk vs RAM insignificant for most caching purposes. Simply put, you're now usually better off keeping a huge cache on disk rather than a small cache in memory.

## Installation

Solid Cache is configured by default in new Rails 8 applications. But if you're running an earlier version, you can add it manually following these steps:

1. `bundle add solid_cache`
2. `bin/rails solid_cache:install`

This will configure Solid Cache as the production cache store and create `config/cache.yml`.

## Configuration

Configuration will be read from `config/cache.yml` or `config/solid_cache.yml`. You can change the location of the config file by setting the `SOLID_CACHE_CONFIG` env variable.

The format of the file is:

```yml
default: &default
  # database: <%= ENV.fetch("SOLID_CACHE_DATABASE", "solid_cache") %>
  # collection: solid_cache_entries
  # client: default
  # encrypt: false
  store_options:
    # Cap age of oldest cache entry to fulfill retention policies
    # max_age: <%%= 60.days.to_i %>
    max_size: <%%= 256.megabytes %>
    namespace: <%%= Rails.env %>

development:
  <<: *default

test:
  <<: *default

production:
  database: <%= ENV.fetch("SOLID_CACHE_DATABASE", "solid_cache") %>
  <<: *default

```

For the full list of keys for `store_options` see [Cache configuration](#cache-configuration). Any options passed to the cache lookup will overwrite those specified here.

After running `solid_cache:install`, `environments/production.rb` will replace your cache store with Solid Cache, but you can also do this manually:

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```
### Engine configuration

There are five options that can be set on the engine:

- `executor` - the [Rails executor](https://guides.rubyonrails.org/threading_and_code_execution.html#executor) used to wrap asynchronous operations, defaults to the app executor
- `size_estimate_samples` - if `max_size` is set on the cache, the number of the samples used to estimate the size.
- `encrypted` - whether cache values should be encrypted (see [Enabling encryption](#enabling-encryption))
- `encryption_context_properties` - custom encryption context properties

These can be set in your Rails configuration:

```ruby
Rails.application.configure do
  config.solid_cache.size_estimate_samples = 1000
end
```

### Cache configuration

Solid Cache supports these options in addition to the standard `ActiveSupport::Cache::Store` options:

- `error_handler` - a Proc to call to handle any transient database errors that are raised (default: log errors as warnings)
- `expiry_batch_size` - the batch size to use when deleting old records (default: `100`)
- `expiry_method` - what expiry method to use `thread` or `job` (default: `thread`)
- `expiry_queue` - which queue to add expiry jobs to (default: `default`)
- `max_age` - the maximum age of entries in the cache (default: `2.weeks.to_i`). Can be set to `nil`, but this is not recommended unless using `max_entries` to limit the size of the cache.
- `max_entries` - the maximum number of entries allowed in the cache (default: `nil`, meaning no limit)
- `max_size` - the maximum size of the cache entries (default `nil`, meaning no limit)
- `cluster` - (deprecated) a Hash of options for the cache database cluster, e.g `{ shards: [:database1, :database2, :database3] }`
- `clusters` - (deprecated) an Array of Hashes for multiple cache clusters (ignored if `:cluster` is set)
- `shards` - an Array of databases
- `active_record_instrumentation` - whether to instrument the cache's queries (default: `true`)
- `clear_with` - clear the cache with `:truncate` or `:delete` (default `truncate`, except for when `Rails.env.test?` then `delete`)
- `max_key_bytesize` - the maximum size of a normalized key in bytes (default `1024`)

## Cache expiry

Solid Cache tracks writes to the cache. For every write it increments a counter by 1. Once the counter reaches 50% of the `expiry_batch_size` it adds a task to run on a background thread. That task will:

1. Check if we have exceeded the `max_entries` or `max_size` values (if set).
   The current entries are estimated by subtracting the max and min IDs from the `SolidCache::Entry` table.
   The current size is estimated by sampling the entry `byte_size` columns.
2. If we have, it will delete `expiry_batch_size` entries.
3. If not, it will delete up to `expiry_batch_size` entries, provided they are all older than `max_age`.

Expiring when we reach 50% of the batch size allows us to expire records from the cache faster than we write to it when we need to reduce the cache size.

Only triggering expiry when we write means that if the cache is idle, the background thread is also idle.

If you want the cache expiry to be run in a background job instead of a thread, you can set `expiry_method` to `:job`. This will enqueue a `SolidCache::ExpiryJob`.

## Enabling encryption

To encrypt the cache values, you can add the encrypt property.

```yaml
# config/cache.yml
production:
  encrypt: true
```
or
```ruby
# application.rb
config.solid_cache.encrypt = true
```

You will need to set up your application to [use Active Record Encryption](https://www.mongodb.com/docs/mongoid/current/security/encryption).

Solid Cache by default uses a custom encryptor and message serializer that are optimised for it.
You can choose your own context properties instead if you prefer:

```ruby
# application.rb
config.solid_cache.encryption_context_properties = {
  deterministic: false
}
```

## Index size limits
The Solid Cache migrations try to create an index with 1024 byte entries. If that is too big for your database, you should:

1. Edit the index size in the migration.
2. Set `max_key_bytesize` on your cache to the new value.

## Development

Run the tests with `bin/rake test`. By default, these will run against SQLite.

You can also run the tests against MySQL and PostgreSQL. First start up the databases:

```shell
$ docker compose up -d
```

Next, setup the database schema:

```shell
$ TARGET_DB=mysql bin/rails db:setup
$ TARGET_DB=postgres bin/rails db:setup
```


Then run the tests for the target database:

```shell
$ TARGET_DB=mysql bin/rake test
$ TARGET_DB=postgres bin/rake test
```

### Testing with multiple Rails versions

Solid Cache relies on [appraisal](https://github.com/thoughtbot/appraisal/tree/main) to test
multiple Rails versions.

To run a test for a specific version run:

```shell
bundle exec appraisal rails-7-1 bin/rake test
```

After updating the dependencies in the `Gemfile` please run:

```shell
$ bundle
$ appraisal update
```

This ensures that all the Rails versions dependencies are updated.

## Implementation

Solid Cache is a FIFO (first in, first out) cache. While this is not as efficient as an LRU (least recently used) cache, it is mitigated by the longer cache lifespan.

A FIFO cache is much easier to manage:
1. We don't need to track when items are read.
2. We can estimate and control the cache size by comparing the maximum and minimum IDs.
3. By deleting from one end of the table and adding at the other end we can avoid fragmentation (on MySQL at least).


## Upgrading

**Upgrading from v0.3.0 or earlier? Please see [upgrading to version v0.4.x and beyond](upgrading_to_version_0.4.x.md)**

## License
Solid Cache is licensed under MIT.
