# frozen_string_literal: true

# Check and make sure we are registered with TurnItIn for
# all web hook callbacks
class TiiGroupAttachmentJob
  include Sidekiq::Job

  # Upload new group attachment for provided templates for a given task definition
  def perform(task_def_id)
    td = TaskDefinition.find(task_def_id)
    TurnItIn.send_group_attachments_to_tii(td)
  end
end
