class ModeratedTask < ApplicationRecord
  belongs_to :task
  belongs_to :task_definition
  belongs_to :user, optional: true

  enum :state, {
    open: 'open',
    waiting_for_new_feedback: 'waiting_for_new_feedback',
    resolved: 'resolved'
  }

  enum :moderation_type, {
    first_feedback: 'first_feedback',
    sample: 'sample',
    escalation: 'escalation'
  }
end
