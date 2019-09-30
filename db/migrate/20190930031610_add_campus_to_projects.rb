class AddCampusToProjects < ActiveRecord::Migration
  def change
    add_reference :projects, :campus, index: true
    add_foreign_key :projects, :campuses
  end
end
