class AddPlagiarismPctCache < ActiveRecord::Migration[4.2]
  def change
  	add_column :tasks, :max_pct_similar, :integer, :default => 0
  	add_column :projects, :max_pct_similar, :integer, :default => 0
  end
end
