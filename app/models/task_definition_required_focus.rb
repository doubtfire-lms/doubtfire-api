class TaskDefinitionRequiredFocus < ApplicationRecord
  belongs_to :task_definition, optional: false
  belongs_to :focus, optional: false
end
