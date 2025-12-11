# frozen_string_literal: true

module SolidCache
  module Record
    extend ActiveSupport::Concern
    include Mongoid::Document
    include Mongoid::Timestamps
    include Mongoid::Locker
    included do
      NULL_INSTRUMENTER = ActiveSupport::Notifications::Instrumenter.new(ActiveSupport::Notifications::Fanout.new)

      encrypt_with(key_id: ENV.fetch("SOLID_CACHE_KEY_ENCRYPT", nil) || Rails.application.secret_key_base) if SolidCache.configuration.encrypt?

      field :key, type: BSON::Binary, encrypt: SolidCache.configuration.encryption_context_properties
      field :value, type: BSON::Binary, encrypt: SolidCache.configuration.encryption_context_properties
      field :key_hash, type: Integer
      field :byte_size, type: Integer
      field :locking_name, type: String
      field :locked_at, type: Time

      index({ byte_size: 1 })
      index({ key_hash: 1, byte_size: 1 })
      index({ key_hash: 1 }, { unique: true })

      store_in collection: SolidCache.configuration.collection if SolidCache.configuration.collection.present?
      store_in client: SolidCache.configuration.client if SolidCache.configuration.client.present?
      store_in database: SolidCache.configuration.database if SolidCache.configuration.database.present?
    end

    class_methods do
      def disable_instrumentation(&block)
        with_instrumenter(NULL_INSTRUMENTER, &block)
      end

      def with_instrumenter(instrumenter)
        if ActiveSupport::Notifications.respond_to?(:instrumenter) && ActiveSupport::Notifications.respond_to?(:instrumenter=)
          old = ActiveSupport::Notifications.instrumenter
          ActiveSupport::Notifications.instrumenter = instrumenter
          begin
            yield
          ensure
            ActiveSupport::Notifications.instrumenter = old
          end
        else
          # Fallback al comportamiento previo que usaba IsolatedExecutionState
          old = ActiveSupport::IsolatedExecutionState[:active_record_instrumenter]
          ActiveSupport::IsolatedExecutionState[:active_record_instrumenter] = instrumenter
          begin
            yield
          ensure
            ActiveSupport::IsolatedExecutionState[:active_record_instrumenter] = old
          end
        end
      end

      def without_query_cache(&block)
        Mongo::QueryCache.uncached(&block)
      end
      alias :uncached :without_query_cache

      def with_query_cache(&block)
        Mongo::QueryCache.cache(&block)
      end
      alias :cache :with_query_cache

      def lease_connection
        # Obtiene el cliente Mongo actual del modelo
        client = self.mongo_client

        # Asegura que hay una conexión disponible
        client.reconnect unless client.cluster.connected?

        yield client
      end
    end
  end
end
