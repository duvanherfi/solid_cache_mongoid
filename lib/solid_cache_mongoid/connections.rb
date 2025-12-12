# frozen_string_literal: true

module SolidCacheMongoid
  module Connections
    def self.from_config(_ = nil)
      Unmanaged.new
    end
  end
end
