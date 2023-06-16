class CriterionOption < ApplicationRecord
  # Associations
  belongs_to :criterion
  belongs_to :task_status
  has_many :feedback_comment_templates
  has_many :feedback_comments

  # Constraints
  validates_associated :criterion
end
