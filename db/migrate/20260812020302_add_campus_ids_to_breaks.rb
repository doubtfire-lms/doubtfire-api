class AddCampusIdsToBreaks < ActiveRecord::Migration[8.0]
  def change
    add_column :breaks, :campus_ids, :json, null: false, default: []
  end
end
