class DiscussTimeoutComment < TaskComment
  WARNING_CONTENT_TYPE = 'discuss_timeout_warning'.freeze
  EXPIRED_CONTENT_TYPE = 'discuss_timeout_expired'.freeze

  before_create do
    self.attention_audience = :student
  end

  def self.warning
    WARNING_CONTENT_TYPE
  end

  def self.expired
    EXPIRED_CONTENT_TYPE
  end
end
