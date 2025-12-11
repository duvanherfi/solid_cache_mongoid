# frozen_string_literal: true

module SolidCache
  class ExpiryJob < ActiveJob::Base
    def perform(count, max_age: nil, max_entries: nil, max_size: nil)
      Entry.expire(count, max_age: max_age, max_entries: max_entries, max_size: max_size)
    end
  end
end
