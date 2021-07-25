class AddRoomToTutorialsTable < ActiveRecord::Migration
  def change
    add_column :tutorials, :room_id, :integer, null: true
  end
end
