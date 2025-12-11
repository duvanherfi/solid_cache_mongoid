# frozen_string_literal: true

require "test_helper"

class SolidCache::ConfigurationTest < ActiveSupport::TestCase
  test "database option accepts a single database name" do
    config = SolidCache::Configuration.new(database: :cache)
    assert_equal(:cache, config.database)
  end
end
