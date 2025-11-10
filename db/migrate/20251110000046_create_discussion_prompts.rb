class CreateDiscussionPrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :discussion_prompts do |t|
      t.references :task_definition, null: false
      t.references :project, null: true
      t.references :created_by, index: true, null: true
      t.text :content, null: false, limit: 4096
      t.integer :weight, default: 0
      t.datetime :discussed_at
      t.timestamps
    end
  end
end
