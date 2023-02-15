# frozen_string_literal: true

require 'tempfile'

class TaskComment < Message

  belongs_to :task, optional: false # Foreign key

  validates :task, presence: true

  def context_object()
    task
  end
end

if Rails.env.development?
  require_dependency 'assessment_comment'
  require_dependency 'discussion_comment'
  require_dependency 'task_status_comment'
  require_dependency 'extension_comment'
end
