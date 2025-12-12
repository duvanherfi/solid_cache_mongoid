# frozen_string_literal: true

require "zeitwerk"
require "solid_cache_mongoid/engine"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/active_support")
loader.ignore("#{__dir__}/generators")
loader.setup

module SolidCacheMongoid
  mattr_accessor :executor
  mattr_accessor :configuration, default: Configuration.new
end

loader.eager_load
