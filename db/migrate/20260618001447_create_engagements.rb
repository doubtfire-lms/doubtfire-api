class CreateEngagements < ActiveRecord::Migration[8.0]
  def change
    create_table :engagements do |t|
      t.references :project, null: false, index: true
      t.references :user, null: false, index: true
      t.string :engagement_type, null: false
      t.text :note, null: false
      t.datetime :occurred_at, null: false
      t.text :evidence_url
      t.string :content_type
      t.string :attachment_extension

      t.timestamps
    end

    create_table :engagement_comments do |t|
      t.references :engagement, null: false, index: true
      t.references :user, null: false, index: true
      t.references :reply_to, null: true, index: true
      t.text :comment, null: false

      t.timestamps
    end

    add_index :engagements, [:project_id, :occurred_at]
  end
end
