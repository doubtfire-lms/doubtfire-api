# frozen_string_literal: true

class EngagementComment < ApplicationRecord
  belongs_to :engagement, optional: false, inverse_of: :engagement_comments
  belongs_to :user, optional: false, inverse_of: :engagement_comments

  validates :comment, presence: true, length: { maximum: 4095 }

  before_validation do
    self.comment = comment&.strip
  end
end
