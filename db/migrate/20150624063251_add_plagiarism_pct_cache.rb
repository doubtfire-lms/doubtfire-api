class AddPlagiarismPctCache < ActiveRecord::Migration
  def change
  	add_column :tasks, :max_pct_similar, :integer, :default => 0
  	add_column :projects, :max_pct_similar, :integer, :default => 0
  end
end
