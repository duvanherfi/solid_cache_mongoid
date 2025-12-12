# frozen_string_literal: true

module SolidCacheMongoid
  class Entry
    module Size
      extend ActiveSupport::Concern

      included do
        scope :largest_byte_sizes, -> (limit) { order(byte_size: :desc).limit(limit).only(:byte_size) }
        scope :in_key_hash_range, -> (range) { where(:key_hash.gte => range.begin, :key_hash.lte => range.end) }
        scope :up_to_byte_size, -> (cutoff) { where(:byte_size.lte => cutoff) }
      end

      class_methods do
        def estimated_size(samples: SolidCacheMongoid.configuration.size_estimate_samples)
          MovingAverageEstimate.new(samples: samples).size
        end
      end
    end
  end
end
