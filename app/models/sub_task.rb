class SubTask < ActiveRecord::Base
  include ApplicationHelper

  default_scope include: :sub_task_definition

  attr_accessible :completion_date, :sub_task_definition_id, :task_id

  # Model associations
  belongs_to :sub_task_definition
  belongs_to :task
end
