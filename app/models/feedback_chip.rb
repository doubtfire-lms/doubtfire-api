class FeedbackChip < ApplicationRecord
  validates :title, presence: true
  validates :parentChipId, presence: true
  validates :childChipId, presence: true
  validates :belongsTo, presence: true
end
