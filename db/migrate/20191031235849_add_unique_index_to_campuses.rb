class AddUniqueIndexToCampuses < ActiveRecord::Migration
  def change
    add_index :campuses, :name, unique: true
    add_index :campuses, :abbreviation, unique: true
  end
end
