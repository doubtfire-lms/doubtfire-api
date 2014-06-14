class ShallowTaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :task_definition_id
end

class TaskUpdateSerializer < ActiveModel::Serializer
  attributes :id, :status, :project_id, :new_stats

  def new_stats
    object.project.task_stats
  end
end

class TaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :completion_date, :task_name, :task_desc, :task_weight, :task_abbr
  

  def task_name
  	object.task_definition.name
  end

  def task_desc
  	object.task_definition.description
  end

  def task_weight
  	object.task_definition.weighting
  end

  def task_abbr
  	object.task_definition.abbreviation
  end
end
