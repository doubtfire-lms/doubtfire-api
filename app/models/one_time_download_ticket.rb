require 'digest'
require 'securerandom'

class OneTimeDownloadTicket
  NONCE_BYTES = 32
  MAX_ISSUE_ATTEMPTS = 3
  CACHE_KEY_PREFIX = 'one-time-download-ticket'.freeze

  class << self
    def issue!(scope:, expires_in:)
      MAX_ISSUE_ATTEMPTS.times do
        nonce = SecureRandom.urlsafe_base64(NONCE_BYTES, false)
        stored = Rails.cache.write(
          cache_key(scope, nonce),
          true,
          expires_in: expires_in,
          unless_exist: true
        )
        return nonce if stored
      end

      raise 'Unable to issue a unique one-time download ticket'
    end

    def consume(scope:, nonce:)
      return false if nonce.blank?

      # Cache deletion is atomic for the shared Redis store. Exactly one
      # concurrent request can therefore consume a given ticket.
      Rails.cache.delete(cache_key(scope, nonce))
    end

    private

    def cache_key(scope, nonce)
      "#{CACHE_KEY_PREFIX}:#{scope}:#{Digest::SHA256.hexdigest(nonce.to_s)}"
    end
  end
end
