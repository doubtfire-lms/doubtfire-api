class AddCampusToTutorials < ActiveRecord::Migration
  def change
    add_reference :tutorials, :campus, index: true
    add_foreign_key :tutorials, :campuses
  end
end
