class TaskSerializer < ActiveModel::Serializer
  attributes :id, :awaiting_signoff, :completion_date
  
  has_one :project, :task_definition
end
