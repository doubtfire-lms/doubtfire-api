class AddRequiresDiscussion < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definitions, :requires_discussion, :boolean, null: false, default: false
  end
end
