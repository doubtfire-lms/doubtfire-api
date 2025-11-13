class CreateDiscussionPrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :discussion_prompts do |t|
      t.references :task_definition, null: false
      t.text :content, null: false, limit: 4096
      t.integer :priority, default: 0
      t.timestamps
    end
  end
end
