# frozen_string_literal: true

require "solid_cache_mongoid"

module ActiveSupport
  module Cache
    SolidCacheMongoidStore = SolidCacheMongoid::Store
  end
end
