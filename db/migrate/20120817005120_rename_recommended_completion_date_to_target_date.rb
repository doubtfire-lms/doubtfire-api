class RenameRecommendedCompletionDateToTargetDate < ActiveRecord::Migration
  def change
    rename_column :task_templates, :recommended_completion_date, :target_date
  end
end
