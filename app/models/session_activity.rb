class SessionActivity < ApplicationRecord
  belongs_to :marking_session
  belongs_to :project, optional: true
  belongs_to :task, optional: true
  belongs_to :task_definition, optional: true

  VALID_ACTIONS = %w[inbox GET PUT assessing].freeze
  validates :action, presence: true, inclusion: { in: VALID_ACTIONS }
end
