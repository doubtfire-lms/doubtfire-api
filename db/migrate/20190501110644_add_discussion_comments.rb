class AddDiscussionComments < ActiveRecord::Migration
  def change
    create_table :discussion_comments do |t|
      t.datetime :time_started
      t.datetime :time_completed
      t.integer :number_of_prompts
      t.timestamps null: false
    end
  end
end
