class TutorialEnrolment < ActiveRecord::Base
  belongs_to :tutorial
  belongs_to :project

  validates :tutorial, presence: true
  validates :project,  presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  validates_uniqueness_of :tutorial, :scope => :project, message: 'already exists for the selected student'

  # Only one tutorial enrolment per stream for each project
  validate :already_enrolled_in_tutorial_stream

  # Ensure that student cannot enrol in tutorial of different campus
  # TODO (stream)
  # validate :campus_must_be_same


  def already_enrolled_in_tutorial_stream
    project.tutorial_enrolments.each do |tutorial_enrolment|
      # If tutorial stream matches, check whether we are updating the current enrolment
      if tutorial.tutorial_stream.eql? tutorial_enrolment.tutorial.tutorial_stream and tutorial.id != tutorial_enrolment.tutorial.id
        errors.add :project, "already enrolled in a tutorial with same tutorial stream"
      end
    end
  end
end
