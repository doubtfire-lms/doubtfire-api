require 'json'
require 'time'

class TestAttempt < ApplicationRecord
  belongs_to :task, optional: false

  has_one :task_definition, through: :task

  has_one :scorm_comment, dependent: :destroy

  delegate :role_for, to: :task
  delegate :student, to: :task

  validates :task_id, presence: true

  def self.permissions
    # TODO: this is all wrong, students should not be able to delete test attempts
    student_role_permissions = [
      :update_attempt
      # :review_own_attempt --  depends on task def settings. See specific_permission_hash method
    ]

    tutor_role_permissions = [
      :review_other_attempt,
      :override_success_status,
      :delete_attempt
    ]

    convenor_role_permissions = [
      :review_other_attempt,
      :override_success_status,
      :delete_attempt
    ]

    nil_role_permissions = []

    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      convenor: convenor_role_permissions,
      nil: nil_role_permissions
    }
  end

  # Used to adjust the review own attempt permission based on task def setting
  def specific_permission_hash(role, perm_hash, _other)
    result = perm_hash[role] unless perm_hash.nil?
    if result && role == :student && task_definition.scorm_allow_review
      result << :review_own_attempt
    end
    result
  end

  # task
  # t.references :task

  # extra non-cmi metadata
  # t.datetime :attempted_time, null:false
  # t.boolean :terminated, default: false

  # fields that must be synced from cmi data whenever it's updated
  # t.boolean :completion_status, default: false
  # t.boolean :success_status, default: false
  # t.float :score_scaled, default: 0

  # scorm datamodel
  # t.text :cmi_datamodel, default: "{}", null: false

  after_initialize if: :new_record? do
    self.attempted_time = Time.now
    task = Task.find(self.task_id)
    learner_name = task.project.student.name
    learner_id = task.project.student.student_id

    init_state = {
      "cmi.completion_status": 'not attempted',
      "cmi.entry": 'ab-initio', # init state
      "cmi.objectives._count": '0', # this counter will be managed on the frontend
      "cmi.interactions._count": '0', # this counter will be managed on the frontend
      "cmi.mode": 'normal',
      "cmi.learner_name": learner_name,
      "cmi.learner_id": learner_id
    }
    self.cmi_datamodel = init_state.to_json
  end

  def cmi_datamodel=(data)
    new_data = JSON.parse(data)

    if self.terminated == true
      raise "Terminated entries should not be updated"
    end

    # set cmi.entry to resume if the attempt is in progress
    if new_data['cmi.completion_status'] == 'incomplete'
      new_data['cmi.entry'] = 'resume'
    end

    # IMPORTANT: always sync any model attributes with cmi values here to ensure consistency!
    # attributes derived from cmi keys: completion_status, success_status, score_scaled
    self.completion_status = new_data['cmi.completion_status'] == 'completed'
    self.success_status = new_data['cmi.success_status'] == 'passed'
    self.score_scaled = new_data['cmi.score.scaled']

    write_attribute(:cmi_datamodel, new_data.to_json)
  end

  def review
    dm = JSON.parse(self.cmi_datamodel)
    if dm['cmi.completion_status'] != 'completed'
      raise "Cannot review incomplete attempts!"
    end

    # when review is requested change the mode to review
    dm['cmi.mode'] = 'review'
    write_attribute(:cmi_datamodel, dm.to_json)
  end

  def override_success_status(new_success_status)
    dm = JSON.parse(self.cmi_datamodel)
    dm['cmi.success_status'] = (new_success_status ? 'passed' : 'failed')
    write_attribute(:cmi_datamodel, dm.to_json)
    self.success_status = dm['cmi.success_status'] == 'passed'
    self.save!
    self.update_scorm_comment
  end

  def add_scorm_comment
    comment = ScormComment.create
    comment.task = task
    comment.user = task.tutor
    comment.comment = success_status_description
    comment.recipient = task.student
    comment.test_attempt = self
    comment.save!

    comment
  end

  def update_scorm_comment
    if self.scorm_comment.present?
      self.scorm_comment.comment = success_status_description
      self.scorm_comment.save!

      return self.scorm_comment
    end

    puts "WARN: Unexpected need to create scorm comment for test attempt: #{self.id}"
    add_scorm_comment
  end

  def success_status_description
    if self.success_status && self.score_scaled == 1
      "Passed without mistakes"
    elsif self.success_status && self.score_scaled < 1
      "Passed"
    else
      "Unsuccessful"
    end
  end
end
