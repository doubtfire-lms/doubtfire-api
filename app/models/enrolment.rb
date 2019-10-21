class Enrolment < ActiveRecord::Base
  belongs_to :tutorial
  belongs_to :project

  validates :tutorial, presence: true
  validates :project,  presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  # For reference, see unique index migrations of unit activity sets
  validates_uniqueness_of :tutorial, :scope => :project, message: 'already exists for the selected student'
end
