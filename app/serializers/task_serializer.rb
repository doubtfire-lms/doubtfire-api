class ShallowTaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :task_definition_id, :processing_pdf, :has_pdf, :include_in_portfolio, :pct_similar, :similar_to_count
end

class TaskUpdateSerializer < ActiveModel::Serializer
  attributes :id, :status, :project_id, :new_stats, :processing_pdf, :include_in_portfolio, :other_projects

  def new_stats
    object.project.task_stats
  end

  def other_projects
    grp = object.group
    others = grp.projects.select { |p| p.id != object.project_id }.map{|p| {id: p.id, new_stats: p.task_stats}}
  end

  def include_other_projects?
    object.group_task? && ! object.group.nil?
  end

end

class TaskStatSerializer < ActiveModel::Serializer
  attributes :id, :task_abbr, :status, :tutorial_id 

  def task_abbr
    object.task_definition.abbreviation
  end

  def task_abbr
    object.task_definition.abbreviation
  end

  # def tutorial_id
  #   object.project.tutorial.id unless object.project.tutorial.nil?
  # end
end

class TaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :completion_date, :task_name, :task_desc, :task_weight, :task_abbr, :upload_requirements, :processing_pdf, :pct_similar, :similar_to_count

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
  
  def upload_requirements
    object.task_definition.upload_requirements
  end
end
