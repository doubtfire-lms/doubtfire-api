class ActivityType < ActiveRecord::Base
  # Relationships
  has_many :unit_activity_sets

  validates :name,         presence: true
  validates :abbreviation, presence: true
end
