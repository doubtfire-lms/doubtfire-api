class ActivityType < ActiveRecord::Base

  validates :name,         presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true
end
