class LearningOutcomeTaskLink < ActiveRecord::Base
  belongs_to :task_definition
  belongs_to :task
  belongs_to :learning_outcome

  validates :task_definition, presence: true
  validates :learning_outcome, presence: true
  validate :ensure_relations_unique

  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }


  def ensure_relations_unique
    return if learning_outcome.nil? || task_definition.nil?
    
    if id.nil?
      related_links = LearningOutcomeTaskLink.where( "task_definition_id = :task_definition_id AND learning_outcome_id = :learning_outcome_id", {my_id: id, task_definition_id: task_definition.id, learning_outcome_id: learning_outcome.id} )
    else
      related_links = LearningOutcomeTaskLink.where( "id != :my_id AND task_definition_id = :task_definition_id AND learning_outcome_id = :learning_outcome_id", {my_id: id, task_definition_id: task_definition.id, learning_outcome_id: learning_outcome.id} )
    end

    if task.nil?
      errors.add(:task_definition, "already linked to this learning outcome") if related_links.where("task_id is NULL").count > 0
    else
      errors.add(:task, "already linked to this learning outcome") if related_links.where("task_id = :task_id", {task_id: task.id}).count > 0
    end
  end
end
