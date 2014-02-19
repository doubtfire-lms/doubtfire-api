class SubTask < ActiveRecord::Base
  include ApplicationHelper

  default_scope include: :sub_task_definition

  # Model associations
  belongs_to :sub_task_definition
  belongs_to :task
end
