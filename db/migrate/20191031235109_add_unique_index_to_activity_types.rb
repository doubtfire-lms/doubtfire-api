class AddUniqueIndexToActivityTypes < ActiveRecord::Migration
  def change
    add_index :activity_types, :name, unique: true
    add_index :activity_types, :abbreviation, unique: true
  end
end
