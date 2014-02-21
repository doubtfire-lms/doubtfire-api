class TaskSerializer < ActiveModel::Serializer
  attributes :id, :awaiting_signoff, :completion_date
  
  has_one :project, serializer: ShallowProjectSerializer
  has_one :task_definition
end
