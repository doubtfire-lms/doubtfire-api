class UnitActivitySet < ActiveRecord::Base
  belongs_to :unit
  belongs_to :activity_type

  has_many :campus_activity_sets, dependent: :destroy
  has_many :tutorials,            dependent: :destroy

  # Always check for presence of whole model instead of id
  # So validate presence of unit not unit_id
  # This ensures that id provided is also valid, so there exists an unit with that id
  validates :activity_type, presence: true
  validates :unit,          presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  # For reference, see unique index migrations of unit activity sets
  validates_uniqueness_of :activity_type, :scope => :unit, message: 'already exists for the unit'
end
