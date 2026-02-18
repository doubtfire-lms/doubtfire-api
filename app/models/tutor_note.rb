class TutorNote < ApplicationRecord
  belongs_to :unit_role
  belongs_to :user
  belongs_to :task, optional: true
  belongs_to :reply_to, class_name: "TutorNote", optional: true

  def task_definition_id
    task&.task_definition&.id
  end

  def project_id
    task&.project&.id
  end
end
