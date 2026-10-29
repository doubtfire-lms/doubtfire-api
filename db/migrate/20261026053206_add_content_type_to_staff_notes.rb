class AddContentTypeToStaffNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :staff_notes, :content_type, :string
  end
end
