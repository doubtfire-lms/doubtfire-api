class TaskPrerequisite < ApplicationRecord
  belongs_to :task_definition
  belongs_to :prerequisite, class_name: "TaskDefinition"

  validate :cannot_be_its_own_prerequisite
  validate :no_reverse_prerequisite
  validates :prerequisite_id, uniqueness: { scope: :task_definition_id, message: "already exists for this task" }

  def no_reverse_prerequisite
    if TaskPrerequisite.exists?(task_definition: prerequisite, prerequisite: task_definition)
      errors.add(:base, "reverse prerequisite already exists")
    end
  end

  def cannot_be_its_own_prerequisite
    if task_definition_id == prerequisite_id
      errors.add(:prerequisite, "cannot be the same as the task definition")
    end
  end
end
