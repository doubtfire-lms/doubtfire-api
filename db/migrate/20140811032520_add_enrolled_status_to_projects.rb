class AddEnrolledStatusToProjects < ActiveRecord::Migration
  def change
  	add_column :projects, :enrolled, :boolean, :default => true
  	add_index :projects, :enrolled
  end
end
