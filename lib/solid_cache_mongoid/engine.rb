# frozen_string_literal: true

require "active_support"
require "mongoid"

module SolidCacheMongoid
  class Engine < ::Rails::Engine
    isolate_namespace SolidCacheMongoid

    config.solid_cache = ActiveSupport::OrderedOptions.new

    initializer "solid_cache_mongoid.config", before: :initialize_cache do |app|
      config_paths = %w[config/cache config/solid_cache_mongoid]

      config_paths.each do |path|
        app.paths.add path, with: ENV["SOLID_CACHE_CONFIG"] || "#{path}.yml"
      end

      config_pathname = config_paths.map { |path| Pathname.new(app.config.paths[path].first) }.find(&:exist?)

      options = config_pathname ? app.config_for(config_pathname).to_h.deep_symbolize_keys : {}

      options[:size_estimate_samples] = config.solid_cache.size_estimate_samples if config.solid_cache.size_estimate_samples
      options[:encrypt] = config.solid_cache.encrypt if config.solid_cache.encrypt
      options[:encryption_context_properties] = config.solid_cache.encryption_context_properties if config.solid_cache.encryption_context_properties

      SolidCacheMongoid.configuration = SolidCacheMongoid::Configuration.new(**options)
    end

    initializer "solid_cache_mongoid.app_executor", before: :run_prepare_callbacks do |app|
      SolidCacheMongoid.executor = config.solid_cache.executor || app.executor
    end

    config.after_initialize do
      Rails.cache.setup! if Rails.cache.is_a?(Store)
    end
  end
end
