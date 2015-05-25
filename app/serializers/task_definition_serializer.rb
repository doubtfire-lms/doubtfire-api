class TaskDefinitionSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :weight, :required, :target_date, :abbreviation, :upload_requirements, :target_grade, :restrict_status_updates

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
