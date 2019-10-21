class CampusActivitySet < ActiveRecord::Base
  belongs_to :campus
  belongs_to :unit_activity_set

  validates :campus,            presence: true
  validates :unit_activity_set, presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  # For reference, see unique index migrations of unit activity sets
  validates_uniqueness_of :unit_activity_set, :scope => :campus, message: 'already exists for the selected campus'
end
