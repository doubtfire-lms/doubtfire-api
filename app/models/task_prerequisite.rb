class TaskPrerequisite < ApplicationRecord
  belongs_to :task_definition
  belongs_to :prerequisite, class_name: "TaskDefinition"

  # validate :prerequisite_due_date_not_after_task
  validate :cannot_be_its_own_prerequisite
  validate :no_reverse_prerequisite
  validates :prerequisite_id, uniqueness: { scope: :task_definition_id, message: "already exists for this task" }
  validate :same_unit
  validate :prerequisite_grade_not_higher

  def prerequisite_due_date_not_after_task
    return unless task_definition && prerequisite
    if prerequisite.target_date > task_definition.target_date
      errors.add(:prerequisite, "due date cannot be later than the task definition's due date")
    end
  end

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

  def same_unit
    if task_definition.unit_id != prerequisite.unit_id
      errors.add(:base, "task definition and prerequisite must belong to the same unit")
    end
  end

  # Prevent HD tasks being set as a prerequisite for a Pass task
  def prerequisite_grade_not_higher
    return if prerequisite.nil? || task_definition.nil?

    if prerequisite.target_grade.present? && task_definition.target_grade.present? &&
       prerequisite.target_grade > task_definition.target_grade
      errors.add(:base, "Prerequisite can not have a higher target grade")
    end
  end
end
