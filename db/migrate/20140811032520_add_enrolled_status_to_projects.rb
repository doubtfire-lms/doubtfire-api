class AddEnrolledStatusToProjects < ActiveRecord::Migration[4.2]
  def change
  	add_column :projects, :enrolled, :boolean, :default => true
  	add_index :projects, :enrolled
  end
end
