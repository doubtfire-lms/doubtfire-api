class LearningOutcome < ActiveRecord::Base
  include ApplicationHelper

  belongs_to :unit

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :related_task_definitions, -> { where("learning_outcome_task_links.task_id is NULL") },  through: :learning_outcome_task_links, source: :task_definition # only link staff relations

  validates_uniqueness_of :abbreviation, scope:  :unit_id   # outcome names within a unit must be unique

end