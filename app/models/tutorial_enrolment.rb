class TutorialEnrolment < ActiveRecord::Base
  belongs_to :tutorial
  belongs_to :project
  
  has_one :tutorial_stream, through: :tutorial

  validates :tutorial, presence: true
  validates :project,  presence: true

  # Always add a unique index to the DB to prevent new records from passing the validations when checked at the same time before being written
  validates_uniqueness_of :tutorial, :scope => :project, message: 'already exists for the selected student'
  
  # Ensure only one tutorial stream per stream
  validate :ensure_only_one_tutorial_per_stream, on: :create

  # Ensure that student cannot enrol in tutorial of different units
  validate :unit_must_be_same

  # Ensure that student cannot enrol in tutorial of different campus
  validate :campus_must_be_same

  # If enrolled in tutorial with no stream, cannot enrol again
  validate :ensure_cannot_have_more_than_one_enrolment_when_tutorial_stream_is_null, on: :create

  # Only one tutorial enrolment per stream for each project
  validate :ensure_max_one_tutorial_enrolment_per_stream

  # Switch from stream to no stream is not allowed
  validate :ensure_cannot_enrol_in_tutorial_with_no_stream_when_enrolled_in_stream

  # Ensure that changes to tutorial enrolments does not invalidate the project
  validates_associated :project

  def unit_must_be_same
    if project.unit.present? and tutorial.unit.present? and not project.unit.eql? tutorial.unit
      errors.add(:project, 'and tutorial belong to different unit')
    end
  end

  def campus_must_be_same
    if project.campus.present? and tutorial.campus.present? and ! project.campus.eql? tutorial.campus
      errors.add(:project, 'and tutorial belong to different campus')
    end
  end

  def ensure_cannot_have_more_than_one_enrolment_when_tutorial_stream_is_null
    if project.tutorial_enrolments
        .joins(:tutorial)
        .where("tutorials.tutorial_stream_id is null")
        .count > 0
      errors.add(:project, 'cannot have more than one enrolment when it is enrolled in tutorial with no stream')
    end
  end

  def ensure_max_one_tutorial_enrolment_per_stream
    # It is valid, unless there is a tutorial enrolment record in the DB that is for the same tutorial stream
    if project.tutorial_enrolments
        .joins(:tutorial)
        .where("(tutorials.tutorial_stream_id = :sid #{ self.id.present? ? 'AND (tutorial_enrolments.id <> :id)' : ''})", sid: tutorial.tutorial_stream_id, id: self.id )
        .count > 0
      errors.add(:project, 'already enrolled in a tutorial with same tutorial stream')
    end
  end

  def ensure_cannot_enrol_in_tutorial_with_no_stream_when_enrolled_in_stream
    if project.tutorial_enrolments
        .joins(:tutorial)
        .where("tutorials.tutorial_stream_id is not null AND :tutorial_stream_id is null AND tutorial_enrolments.id <> :id", tutorial_stream_id: tutorial.tutorial_stream_id, id: id)
        .count > 0
      errors.add(:project, 'cannot enrol in tutorial with no stream when enrolled in stream')
    end
  end

  def ensure_only_one_tutorial_per_stream
    if project.tutorial_enrolments.
        joins(:tutorial).
        where("tutorials.tutorial_stream_id = :sid OR (tutorials.tutorial_stream_id IS NULL AND :sid IS NULL)", sid: tutorial.tutorial_stream_id)
        .count > 0
      errors.add(:tutorial_stream, 'already exists for the selected student')
    end
  end
end
