class CreateTutorNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :tutor_notes do |t|
      t.text :note
      t.references :task, index: true, null: true
      t.references :unit_role, index: true, null: false
      # t.references :unit_roles, :mentor, index: true, null: false
      t.references :user, index: true, null: false
      t.references :tutor_notes, :reply_to, index: true, null: true

      # TODO: Only accessible by users with the convenor role?
      t.boolean :convenor_only, null: false

      t.timestamps
    end
  end
end
