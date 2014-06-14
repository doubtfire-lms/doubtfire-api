class AddProjectStatsCache < ActiveRecord::Migration
  def change
  	add_column :projects, :task_stats, :string
  end
end
