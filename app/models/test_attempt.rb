require 'json'
require 'time'

class TestAttempt < ApplicationRecord

  def self.permissions
    # TODO: this is all wrong, students should not be able to delete test attempts
    student_role_permissions = [
      :create,
      :view_own,
      :delete_own
    ]

    tutor_role_permissions = [
      :create,
      :view_own,
      :delete_own
    ]

    convenor_role_permissions = [
      :create,
      :view_own,
      :delete_own
    ]

    nil_role_permissions = []

    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      convenor: convenor_role_permissions,
      nil: nil_role_permissions
    }
  end

  # task
  # t.references :task

  # extra non-cmi metadata
  # t.datetime :attempted_time, null:false
  # t.integer :attempt_number, default: 1, null: false
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

  def pass_override
    # TODO: implement tutor override pass
  end

end
