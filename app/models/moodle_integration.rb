# frozen_string_literal: true

class MoodleIntegration < ApplicationRecord
  belongs_to :unit

  encrypts :api_key

  validates :course_id, numericality: { only_integer: true, greater_than: 0 }
  validates :assignment_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :unit_id, uniqueness: true
end
