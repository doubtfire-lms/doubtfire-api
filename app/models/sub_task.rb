class SubTask < ActiveRecord::Base
  include ApplicationHelper

  # Model associations
  belongs_to :sub_task_definition
  belongs_to :task
end
