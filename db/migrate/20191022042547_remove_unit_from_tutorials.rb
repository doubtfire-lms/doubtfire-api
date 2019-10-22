class RemoveUnitFromTutorials < ActiveRecord::Migration
  def change
    remove_column :tutorials, :unit_id
  end
end
