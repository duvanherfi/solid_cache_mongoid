# frozen_string_literal: true

module SolidCache
  class Entry < Record
    include Expiration, Size, Mongoid::Locker

    # The estimated cost of an extra row in bytes, including fixed size columns, overhead, indexes and free space
    # Based on experimentation on SQLite, MySQL and Postgresql.
    # A bit high for SQLite (more like 90 bytes), but about right for MySQL/Postgresql.
    ESTIMATED_ROW_OVERHEAD = 140

    # Assuming MessagePack serialization
    ESTIMATED_ENCRYPTION_OVERHEAD = 170

    KEY_HASH_ID_RANGE = -(2**63)..(2**63 - 1)

    MULTI_BATCH_SIZE = 1000

    class << self
      def write(key, value)
        write_multi([ { key: key, value: value } ])
      end

      def write_multi(payloads)
        without_query_cache do
          payloads.each_slice(MULTI_BATCH_SIZE).each do |payload_batch|
            add_key_hash_and_byte_size(payload_batch).each do |payload|
              # Convertir key y value a BSON::Binary
              key = payload.delete(:key)
              value = payload.delete(:value)
              obj = where(key_hash: payload[:key_hash]).first_or_initialize
              obj.assign_attributes(payload)
              obj.key = BSON::Binary.new(key)
              obj.value = BSON::Binary.new(value)
              obj.save
            end
          end
        end
      end

      def read(key)
        read_multi([key])[key]
      end

      def read_multi(keys)
        without_query_cache do
          {}.tap do |results|
            keys.each_slice(MULTI_BATCH_SIZE).each do |keys_batch|
              key_hashes = key_hashes_for(keys_batch)

              where(:key_hash.in => key_hashes)
                .only(:key, :value)
                .each do |entry|
                  # Convertir BSON::Binary de vuelta a string
                  key_str = entry.key.data
                  value_str = entry.value.data
                  results[key_str] = value_str
                end
            end
          end
        end
      end

      def delete_by_key(*keys)
        without_query_cache do
          where(:key_hash.in => key_hashes_for(keys)).delete_all
        end
      end

      def clear_truncate
        delete_all
        nil
      end

      def clear_delete
        without_query_cache do
          delete_all
        end
        nil
      end

      def lock_and_write(key, &block)
        without_query_cache do
          entry = where(key_hash: key_hash_for(key)).first

          if entry
            entry.with_lock do
              entry_key = entry.key.data
              entry_value = entry.value.data

              current_value = entry_key == key ? entry_value : nil
              new_value = block.call(current_value)
              write(key, new_value) if new_value
              new_value
            end
          else
            new_value = block.call(nil)
            write(key, new_value) if new_value
            new_value
          end
        end
      end

      def id_range
        without_query_cache { count }
      end

      private
        def add_key_hash_and_byte_size(payloads)
          payloads.map do |payload|
            payload.dup.tap do |payload|
              payload[:key_hash] = key_hash_for(payload[:key])
              payload[:byte_size] = byte_size_for(payload)
            end
          end
        end

        def key_hash_for(key)
          # Need to unpack this as a signed integer - Postgresql and SQLite don't support unsigned integers
          Digest::SHA256.digest(key.to_s).unpack("q>").first
        end

        def key_hashes_for(keys)
          keys.map { |key| key_hash_for(key) }
        end

        def byte_size_for(payload)
          payload[:key].to_s.bytesize + payload[:value].to_s.bytesize + estimated_row_overhead
        end

        def estimated_row_overhead
          if SolidCache.configuration.encrypt?
            ESTIMATED_ROW_OVERHEAD + ESTIMATED_ENCRYPTION_OVERHEAD
          else
            ESTIMATED_ROW_OVERHEAD
          end
        end
    end
  end
end

ActiveSupport.run_load_hooks :solid_cache_entry, SolidCache::Entry
