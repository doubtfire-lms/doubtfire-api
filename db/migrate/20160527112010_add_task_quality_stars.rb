class AddTaskQualityStars < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :quality_pts, :integer, default: 0
    add_column :task_definitions, :max_quality_pts, :integer, default: 0
  end
end
