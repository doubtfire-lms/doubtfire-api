class CreateStaffNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :staff_notes do |t|
      t.text :note
      t.references :project, index: true, null: false
      t.references :user, index: true, null: false
      t.references :staff_notes, :reply_to, index: true, null: true

      t.timestamps
    end
  end
end
