# frozen_string_literal: true

class EngagementComment < ApplicationRecord
  belongs_to :engagement, optional: false, inverse_of: :engagement_comments
  belongs_to :user, optional: false, inverse_of: :engagement_comments
  belongs_to :reply_to, class_name: 'EngagementComment', optional: true
  has_many :replies,
           class_name: 'EngagementComment',
           foreign_key: :reply_to_id,
           dependent: :nullify,
           inverse_of: :reply_to

  validates :comment, presence: true, length: { maximum: 4095 }
  validate :reply_belongs_to_engagement

  before_validation do
    self.comment = comment&.strip
  end

  private

  def reply_belongs_to_engagement
    return if reply_to.nil? || reply_to.engagement_id == engagement_id

    errors.add(:reply_to, 'must belong to the same engagement')
  end
end
