class TutorialEnrolment < ActiveRecord::Base
  belongs_to :tutorial
  belongs_to :project

  validates :tutorial, presence: true
  validates :project,  presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  validates_uniqueness_of :tutorial, :scope => :project, message: 'already exists for the selected student'

  # Only one tutorial enrolment per stream for each project
  validate :ensure_max_one_tutorial_enrolment_per_stream

  # Ensure that student cannot enrol in tutorial of different campus
  # TODO (stream)
  # validate :campus_must_be_same


  def ensure_max_one_tutorial_enrolment_per_stream
    # It is valid, unless there is a tutorial enrolment record in the DB that is for the same tutorial stream
    if project.tutorial_enrolments
        .joins(:tutorial)
        .where("tutorials.tutorial_stream_id = :sid #{ self.id.present? ? 'AND (tutorial_enrolments.id <> :id)' : ''}", sid: tutorial.tutorial_stream_id, id: self.id )
        .count > 0
      errors.add(:project, 'already enrolled in a tutorial with same tutorial stream')
    end
  end
end
