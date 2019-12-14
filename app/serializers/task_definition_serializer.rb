# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class TaskDefinitionSerializer < ActiveModel::Serializer
  attributes :id, :abbreviation, :name, :description,
             :weight, :target_grade, :target_date,
             :upload_requirements,
             :plagiarism_checks, :plagiarism_report_url, :plagiarism_warn_pct,
             :restrict_status_updates,
             :group_set_id, :has_task_sheet?, :has_task_resources?,
             :due_date, :start_date, :is_graded, :max_quality_pts

  def weight
    object.weighting
  end
end
