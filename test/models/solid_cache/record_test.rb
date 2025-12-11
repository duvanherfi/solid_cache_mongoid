# frozen_string_literal: true

require "test_helper"

module SolidCache
  class RecordTest < ActiveSupport::TestCase
    SINGLE_DB_CONFIGS = [ "config/cache_database.yml", "config/cache_unprepared_statements.yml" ]

    test "each_database" do
      database = SolidCache::Record.storage_options[:database]
      case ENV["SOLID_CACHE_CONFIG"]
      when "config/cache_no_database.yml"
        assert_equal nil, database
      when "config/cache_database.yml"
        assert_equal :primary, database
      when "config/cache_unprepared_statements.yml"
        assert_equal :primary_unprepared_statements, database
      end
    end
  end
end
