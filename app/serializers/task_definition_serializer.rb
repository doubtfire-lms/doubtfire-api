class TaskDefinitionSerializer < ActiveModel::Serializer
  attributes :id, :name, :desc, :weight, :required, :target_date, :abbr, :upload_requirements, :target_grade

  def abbr
  	object.abbreviation
  end

  def desc
  	object.description
  end

  def weight
  	object.weighting
  end
end
