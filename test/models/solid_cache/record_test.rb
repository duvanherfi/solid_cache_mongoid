# frozen_string_literal: true

require "test_helper"

module SolidCache
  class RecordTest < ActiveSupport::TestCase

    test "each_database" do
      database = SolidCache::Record.storage_options[:database]
      case ENV["SOLID_CACHE_CONFIG"]
      when "config/cache_no_database.yml"
        assert_equal "solid_cache", database
      when "config/cache_database.yml"
        assert_equal "solid_cache", database
      end
    end
  end
end
