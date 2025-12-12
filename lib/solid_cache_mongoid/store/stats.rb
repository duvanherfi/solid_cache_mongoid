# frozen_string_literal: true

module SolidCacheMongoid
  class Store
    module Stats
      def initialize(options = {})
        super(options)
      end

      def stats
        {
          connections: 1,
          connection_stats: connection_stats
        }
      end

      private
        def connection_stats
          oldest_created_at = Entry.order_by([:id, :asc]).pick(:created_at)

          {
            max_age: max_age,
            oldest_age: oldest_created_at ? Time.now - oldest_created_at : nil,
            max_entries: max_entries,
            entries: Entry.id_range
          }
        end
    end
  end
end
