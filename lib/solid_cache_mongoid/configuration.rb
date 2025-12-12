# frozen_string_literal: true

module SolidCacheMongoid
  class Configuration
    attr_reader :store_options, :database, :client, :collection, :executor, :size_estimate_samples, :encrypt, :encryption_context_properties

    def initialize(
      store_options: {}, database: nil, collection: nil, client: nil,
      executor: nil, encrypt: false, encryption_context_properties: nil, size_estimate_samples: 10_000
    )
      @store_options = store_options
      @size_estimate_samples = size_estimate_samples
      @executor = executor
      @encrypt = encrypt
      @client = client
      @collection = collection || "solid_cache_entries"
      @database = database || "solid_cache_mongoid"
      @encryption_context_properties = encryption_context_properties
      @encryption_context_properties ||= default_encryption_context_properties if encrypt?
    end

    def encrypt?
      encrypt.present?
    end

    private
      def default_encryption_context_properties
        { deterministic: false }
      end
  end
end
