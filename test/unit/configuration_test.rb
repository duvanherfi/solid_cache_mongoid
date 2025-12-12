# frozen_string_literal: true

require "test_helper"

class SolidCacheMongoid::ConfigurationTest < ActiveSupport::TestCase
  test "database option accepts a single database name" do
    config = SolidCacheMongoid::Configuration.new(database: :cache)
    assert_equal(:cache, config.database)
  end
end
