class AddProjectStatsCache < ActiveRecord::Migration[4.2]
  def change
  	add_column :projects, :task_stats, :string
  end
end
