class TaskDefinitionSerializer < ActiveModel::Serializer
  attributes :id, :abbreviation, :name, :description, 
    :weight, :required, :target_grade, :target_date, 
    :upload_requirements, 
    :plagiarism_checks, :plagiarism_report_url, :plagiarism_warn_pct,
    :restrict_status_updates,
    :group_set_id

  def weight
  	object.weighting
  end
end
