class LearningOutcomeTaskLink < ActiveRecord::Base
  belongs_to :task_definition
  belongs_to :task
  belongs_to :learning_outcome

  validate :ensure_relations_unique

  def ensure_relations_unique
    related_links = LearningOutcomeTaskLink.where( "task_definition_id = :task_definition_id AND learning_outcome_id = :learning_outcome_id", {task_definition_id: task_definition.id, learning_outcome_id: learning_outcome.id} )
    if task.nil?
      errors.add(:task_definition, "already linked to the learning outcome") if related_links.where("task_id is NULL").count > 0
    else
      errors.add(:task, "already linked to the learning outcome") if related_links.where("task_id = :task_id", {task_id: task.id}).count > 0
    end
  end
end
