# frozen_string_literal: true

require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::StatsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  def test_stats_with_entries_no_shards
    skip unless ENV["SOLID_CACHE_CONFIG"] == "config/cache_no_database.yml"

    @cache = lookup_store(expiry_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000)

    expected_empty = {
      connections: 1,
      connection_stats: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
    }

    assert_equal expected_empty, @cache.stats

    freeze_time
    @cache.write("foo", 1)
    @cache.write("bar", 1)

    SolidCache::Entry.update_all(created_at: Time.now - 20.minutes)

    expected_not_empty = {
      connections: 1,
      connection_stats: { max_age: 2.weeks.to_i, oldest_age: 20.minutes.to_i, max_entries: 1000, entries: 2 }
    }
    assert_equal expected_not_empty, @cache.stats
  end

  def test_stats_with_entries
    skip if ENV["SOLID_CACHE_CONFIG"]

    @cache = lookup_store(expiry_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000)

    expected_empty = {
      connections: 1,
      connection_stats: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
    }

    assert_equal expected_empty, @cache.stats

    freeze_time
    @cache.write("foo", 1)
    @cache.write("bar", 1)

    SolidCache::Entry.update_all(created_at: Time.now - 20.minutes)

    stats = @cache.stats

    assert_equal 20.minutes.to_i, stats[:connection_stats][:oldest_age]
    assert_equal 2, stats[:connection_stats][:entries]
  end

  def test_stats_one_shard
    skip if ENV["SOLID_CACHE_CONFIG"]

    @cache = lookup_store(expiry_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000)

    expected = {
      connections: 1,
      connection_stats: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
    }

    assert_equal expected, @cache.stats
  end

  def test_stats_multiple_shards
    skip if ENV["SOLID_CACHE_CONFIG"]

    @cache = lookup_store(expiry_batch_size: 2, max_age: 2.weeks.to_i, max_entries: 1000)

    expected = {
      connections: 1,
      connection_stats: { max_age: 2.weeks.to_i, oldest_age: nil, max_entries: 1000, entries: 0 }
    }

    assert_equal expected, @cache.stats
  end
end
