# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"
require "debug"
require "mocha/minitest"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_paths.first + "/files"
  ActiveSupport::TestCase.fixtures :all
end

class ActiveSupport::TestCase
  setup do
    @all_stores = []
    SolidCacheMongoid::Entry.delete_all
    SolidCacheMongoid::Entry.remove_indexes
    SolidCacheMongoid::Entry.create_indexes
  end

  teardown do
    @all_stores.each do |store|
      wait_for_background_tasks(store)
    end
  end

  def lookup_store(options = {})
    store_options = { namespace: @namespace }.merge(options)
    ActiveSupport::Cache.lookup_store(:solid_cache_mongoid_store, store_options).tap do |store|
      @all_stores << store
    end
  end

  def cleanup_stores
  end

  def send_entries_back_in_time(distance)
    SolidCacheMongoid::Entry.uncached do
      SolidCacheMongoid::Entry.all.each do |entry|
        entry.update_attributes(created_at: entry.created_at - distance)
      end
    end
  end

  def wait_for_background_tasks(cache, timeout: 2)
    timeout_at = Time.now + timeout
    threadpool = cache.instance_variable_get("@background")

    loop do
      break if threadpool.completed_task_count == threadpool.scheduled_task_count
      raise "Timeout waiting for cache background tasks" if Time.now > timeout_at
      sleep 0.001
    end
  end

  def uncached_entry_count
    SolidCacheMongoid::Entry.uncached { SolidCacheMongoid::Entry.count }
  end

  def emulating_timeouts
    ar_methods = [ :where, :delete_all ]
    stub_matcher = SolidCacheMongoid::Entry
    ar_methods.each { |method| stub_matcher.stubs(method).raises(Mongo::Error::TimeoutError) }
    yield
  ensure
    ar_methods.each { |method| stub_matcher.unstub(method) }
  end
end
