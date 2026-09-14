require 'digest'
require 'securerandom'

class OneTimeDownloadTicket
  NONCE_BYTES = 32
  MAX_ISSUE_ATTEMPTS = 3
  CACHE_KEY_PREFIX = 'one-time-download-ticket'.freeze

  class << self
    def issue!(scope:, expires_in:)
      expires_at = Time.current.to_f + expires_in.to_f

      MAX_ISSUE_ATTEMPTS.times do
        nonce = SecureRandom.urlsafe_base64(NONCE_BYTES, false)
        stored = Rails.cache.write(
          cache_key(scope, nonce),
          expires_at,
          expires_in: expires_in,
          unless_exist: true
        )
        return nonce if stored
      end

      raise 'Unable to issue a unique one-time download ticket'
    end

    def consume(scope:, nonce:)
      return false if nonce.blank?

      key = cache_key(scope, nonce)

      # `delete` reports presence, not liveness: in-process stores keep expired
      # entries until read or pruned. Reading first is expiry aware everywhere.
      expires_at = Rails.cache.read(key)

      # Cache deletion is atomic for the shared Redis store. Exactly one
      # concurrent request can therefore consume a given ticket.
      return false unless Rails.cache.delete(key)

      expires_at.is_a?(Numeric) && Time.current.to_f <= expires_at
    end

    private

    def cache_key(scope, nonce)
      "#{CACHE_KEY_PREFIX}:#{scope}:#{Digest::SHA256.hexdigest(nonce.to_s)}"
    end
  end
end
