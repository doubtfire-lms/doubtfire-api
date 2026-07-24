class DiscussTimeoutComment < TaskComment
  WARNING_CONTENT_TYPE = 'discuss_timeout_warning'.freeze
  EXPIRED_CONTENT_TYPE = 'discuss_timeout_expired'.freeze

  def self.warning
    WARNING_CONTENT_TYPE
  end

  def self.expired
    EXPIRED_CONTENT_TYPE
  end
end
