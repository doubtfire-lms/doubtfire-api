class RenameRecommendedCompletionDateToTargetDate < ActiveRecord::Migration
  def up
    rename_column :task_templates, :recommended_completion_date, :target_date
  end

  def down
    add_column :task_templates, :target_date, :recommended_completion_date
  end
end
