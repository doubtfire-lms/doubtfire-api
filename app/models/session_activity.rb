class SessionActivity < ApplicationRecord
  belongs_to :marking_session
  belongs_to :project, optional: true
  belongs_to :task, optional: true
  belongs_to :task_definition, optional: true

  VALID_ACTIONS = %w[inbox GET PUT assessing add-comment edit-comment get-comments delete-comment get-comment-attachment mark-comment-unread get-submission-details get-submission-files].freeze
  validates :action, presence: true, inclusion: { in: VALID_ACTIONS }
end
