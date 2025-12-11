# frozen_string_literal: true

require "test_helper"
require "active_support/testing/method_call_assertions"

class SolidCache::ExecutionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @cache = nil
    @namespace = "test-#{SecureRandom.hex}"

    @cache = lookup_store(expiry_batch_size: 2, shards: nil)
  end

  def test_async_errors_are_reported
    error_subscriber = ErrorSubscriber.new
    Rails.error.subscribe(error_subscriber)

    @cache.send(:async) do
      raise "Boom!"
    end

    sleep 0.1
    assert_equal 1, error_subscriber.errors.count
    assert_equal "Boom!", error_subscriber.errors.first[0].message
    if Rails.version >= "7.1"
      assert_equal({ context: {}, handled: false, level: :error, source: "application.active_support" }, error_subscriber.errors.first[1])
    else
      assert_equal({ context: {}, handled: false, level: :error, source: nil }, error_subscriber.errors.first[1])
    end
  ensure
    Rails.error.unsubscribe(error_subscriber) if Rails.error.respond_to?(:unsubscribe)
    @all_stores = [] #  to avoid waiting for background tasks as the error one won't have completed
  end

  def test_no_connections_uninstrumented
    SolidCache::Entry.any_of.stubs(:collection).raises(Mongo::Error::TimeoutError)

    cache = lookup_store(expires_in: 60, active_record_instrumentation: false)

    assert_nil cache.write("1", "fsjhgkjfg")
    assert_nil cache.read("1")
    assert_nil cache.increment("1")
    assert_nil cache.decrement("1")
    assert_equal false, cache.delete("1")
    assert_equal({}, cache.read_multi("1", "2", "3"))
    assert_equal false, cache.write_multi("1" => "a", "2" => "b", "3" => "c")
  end

  def test_no_connections_instrumented
    SolidCache::Entry.stubs(:collection).raises(Mongo::Error::TimeoutError)

    cache = lookup_store(expires_in: 60)

    assert_nil cache.write("1", "fsjhgkjfg")
    assert_nil cache.read("1")
    assert_nil cache.increment("1")
    assert_nil cache.decrement("1")
    assert_equal false, cache.delete("1")
    assert_equal({}, cache.read_multi("1", "2", "3"))
    assert_equal false, cache.write_multi("1" => "a", "2" => "b", "3" => "c")
  end

  class ErrorSubscriber
    attr_reader :errors

    def initialize
      @errors = []
    end

    def report(error, handled:, severity:, context:, source: nil)
      errors << [ error, { context: context, handled: handled, level: severity, source: source } ]
    end
  end

  private
    def connection
      Rails.version >= "7.2" ? :lease_connection : :connection
    end
end
