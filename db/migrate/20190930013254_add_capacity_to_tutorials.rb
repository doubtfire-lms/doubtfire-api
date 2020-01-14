class AddCapacityToTutorials < ActiveRecord::Migration
  def change
    add_column :tutorials, :capacity, :integer
  end
end
