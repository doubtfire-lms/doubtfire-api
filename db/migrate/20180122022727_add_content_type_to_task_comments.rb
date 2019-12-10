class AddContentTypeToTaskComments < ActiveRecord::Migration[4.2]
  def change
    add_column :task_comments, :content_type, :string
  end
end
