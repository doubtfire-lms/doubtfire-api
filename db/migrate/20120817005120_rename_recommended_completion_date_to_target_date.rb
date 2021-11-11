class RenameRecommendedCompletionDateToTargetDate < ActiveRecord::Migration[4.2]
  def change
    rename_column :task_templates, :recommended_completion_date, :target_date
  end
end
