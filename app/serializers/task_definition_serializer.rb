class TaskDefinitionSerializer < ActiveModel::Serializer
  attributes :id, :abbreviation, :name, :description, 
    :weight, :target_grade, :target_date, 
    :upload_requirements, 
    :plagiarism_checks, :plagiarism_report_url, :plagiarism_warn_pct,
    :restrict_status_updates,
    :group_set_id, :has_task_pdf?, :has_task_resources?

  def weight
  	object.weighting
  end
end
