# frozen_string_literal: true

require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::ExpiryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  setup do
    @namespace = "test-#{SecureRandom.hex}"
  end

  teardown do
    wait_for_background_tasks(@cache) if @cache
  end

  [ :thread, :job ].each do |expiry_method|
    test "expires old records (#{expiry_method})" do
      SolidCache::Store.any_instance.stubs(:rand).returns(0)

      @cache = lookup_store(expiry_batch_size: 3, max_age: 2.weeks, expiry_method: expiry_method)
      default_shard_keys = "key"
      @cache.write(default_shard_keys, 1)
      @cache.write(default_shard_keys, 2)
      assert_equal 2, @cache.read(default_shard_keys)

      send_entries_back_in_time(3.weeks)

      @cache.write(default_shard_keys, 3)
      @cache.write(default_shard_keys, 4)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_nil @cache.read(default_shard_keys)
      assert_nil @cache.read(default_shard_keys)
    end

    test "expires records when the cache is full (#{expiry_method})" do
      SolidCache::Store.any_instance.stubs(:rand).returns(0)

      @cache = lookup_store(expiry_batch_size: 3, max_age: nil, max_entries: 2, expiry_method: expiry_method)
      default_shard_keys = "key2"
      @cache.write(default_shard_keys, 1)
      @cache.write(default_shard_keys, 2)

      wait_for_background_tasks(@cache)

      @cache.write(default_shard_keys, 3)
      @cache.write(default_shard_keys, 4)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      # Two records have been deleted
      assert_equal 1, SolidCache::Entry.count
    end

    test "expires records when the cache is full via max_size (#{expiry_method})" do
      SolidCache::Store.any_instance.stubs(:rand).returns(0)

      @cache = lookup_store(expiry_batch_size: 3, max_age: nil, max_size: 1000, expiry_method: expiry_method)
      default_shard_keys = "key3"
      @cache.write(default_shard_keys, "a" * 350)
      @cache.write(default_shard_keys, "a" * 350)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      @cache.write(default_shard_keys, "a" * 350)
      @cache.write(default_shard_keys, "a" * 350)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_operator SolidCache::Entry.count, :<, 4
    end

    test "expires records no shards (#{expiry_method})" do
      SolidCache::Store.any_instance.stubs(:rand).returns(0)

      @cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_batch_size: 3, namespace: @namespace, max_entries: 2, expiry_method: expiry_method)
      default_shard_keys = "key4"

      @cache.write("key4", 1)
      @cache.write("key44", 2)

      wait_for_background_tasks(@cache)

      @cache.write("key444", 3)
      @cache.write("key4444", 4)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      # Three records have been deleted
      assert_equal 1, SolidCache::Entry.count
    end

    test "expires when random number is below threshold (#{expiry_method})" do
      SolidCache::Store.any_instance.stubs(:rand).returns(0.416)

      @cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_batch_size: 3, namespace: @namespace, max_entries: 1, expiry_method: expiry_method)
      default_shard_keys = "key5"

      @cache.write(default_shard_keys, 1)
      @cache.write("key55", 2)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_equal 0, SolidCache::Entry.count
    end

    test "doesn't expire when random number is above threshold (#{expiry_method})" do
      SolidCache::Store.any_instance.stubs(:rand).returns(0.417)

      @cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, expiry_batch_size: 6, namespace: @namespace, max_entries: 1, expiry_method: expiry_method)
      default_shard_keys = "key6"

      @cache.write(default_shard_keys, 1)
      @cache.write("key66", 2)

      wait_for_background_tasks(@cache)
      perform_enqueued_jobs

      assert_equal 2, SolidCache::Entry.count
    end
  end

  test "triggers multiple expiry tasks when there are many writes" do
    @cache = lookup_store(expiry_batch_size: 20, max_entries: 2, expiry_queue: :cache_expiry)
    background = @cache.instance_variable_get("@background")

    SolidCache::Store.any_instance.stubs(:rand).returns(0.25, 0.24)
    # We expect 2 expiry job for 8 writes
    assert_difference -> { background.scheduled_task_count }, +1 do
      @cache.write_multi(8.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end

    assert_difference -> { background.scheduled_task_count }, +3 do
      @cache.write_multi(24.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end

    # Whether we overflow an extra job depends on rand
    SolidCache::Store.any_instance.stubs(:rand).returns(0.25, 0.24)
    assert_difference -> { background.scheduled_task_count }, +1 do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end

    assert_difference -> { background.scheduled_task_count }, +1 do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
      wait_for_background_tasks(@cache)
    end
  end

  test "triggers multiple expiry jobs when there are many writes" do
    @cache = lookup_store(expiry_batch_size: 10, max_entries: 4, expiry_queue: :cache_expiry, expiry_method: :job)

    SolidCache::Store.any_instance.stubs(:rand).returns(0.25, 0.24)
    # We expect 1 expiry job for 8 writes
    assert_enqueued_jobs(2, only: SolidCache::ExpiryJob) do
      @cache.write_multi(8.times.index_by { |i| "key#{i}" })
    end

    assert_enqueued_jobs(5, only: SolidCache::ExpiryJob) do
      @cache.write_multi(24.times.index_by { |i| "key#{i}" })
    end

    # Whether we overflow an extra job depends on rand
    SolidCache::Store.any_instance.stubs(:rand).returns(0.125, 0.124)
    assert_enqueued_jobs(2, only: SolidCache::ExpiryJob) do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
    end

    assert_enqueued_jobs(2, only: SolidCache::ExpiryJob) do
      @cache.write_multi(10.times.index_by { |i| "key#{i}" })
    end
  end
end
