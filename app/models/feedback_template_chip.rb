class FeedbackChip < ApplicationRecord
  validates :abbreviation, presence: true
  validates :order, presence: true
  validates :chipText, presence: true
  validates :description, presence: true
  validates :commentText, presence: true
  validates :summaryText, presence: true
  validates :taskStatus, presence: true
end
