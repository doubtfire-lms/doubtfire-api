class ShallowTaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :task_definition_id, :processing_pdf, :has_pdf

  def has_pdf
    File.exists?(PortfolioEvidence.final_pdf_path_for(object))
  end
end

class TaskUpdateSerializer < ActiveModel::Serializer
  attributes :id, :status, :project_id, :new_stats, :processing_pdf

  def new_stats
    object.project.task_stats
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
  attributes :id, :status, :completion_date, :task_name, :task_desc, :task_weight, :task_abbr, :task_upload_requirements, :processing_pdf
  

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
  
  def task_upload_requirements
    object.task_definition.upload_requirements
  end
end
