# frozen_string_literal: true

module Cidadaobr
  class AuthRateLimiter
    WINDOW = 1.minute
    MAX_ATTEMPTS = 20
    CACHE_KEY_PREFIX = "auth_rate_limit"

    class << self
      def blocked?(scope:, key:)
        read_count(scope:, key:) >= MAX_ATTEMPTS
      end

      def record_failure!(scope:, key:)
        cache_key = cache_key_for(scope:, key:)
        backend.increment(cache_key, 1, expires_in: WINDOW, initial: 0)
      end

      def clear_key!(scope:, key:)
        backend.delete(cache_key_for(scope:, key:))
      end

      def reset!
        backend.clear if backend.respond_to?(:clear)
      end

      private

      def read_count(scope:, key:)
        backend.read(cache_key_for(scope:, key:), raw: true).to_i
      end

      def cache_key_for(scope:, key:)
        "#{CACHE_KEY_PREFIX}:#{scope}:#{key}"
      end

      def backend
        cache = Rails.cache
        return cache unless cache.is_a?(ActiveSupport::Cache::NullStore)

        @memory_backend ||= ActiveSupport::Cache.lookup_store(:memory_store)
      end
    end
  end
end
