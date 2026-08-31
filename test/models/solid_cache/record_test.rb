# frozen_string_literal: true

require "test_helper"

module SolidCacheMongoid
  class RecordTest < ActiveSupport::TestCase
    test "the cache lives in its own database" do
      database = SolidCacheMongoid::Entry.storage_options[:database]

      case ENV["SOLID_CACHE_CONFIG"]
      when "config/cache_no_database.yml"
        # No `database` key at all: the gem falls back to its own default
        # rather than to the application's database.
        assert_equal "solid_cache_mongoid", database
      when "config/cache_database.yml"
        # An explicit `database` key wins over that default.
        assert_equal "solid_cache_explicit", database
      end
    end
  end
end
