class AddContentTypeToTaskComments < ActiveRecord::Migration
  def change
    add_column :task_comments, :content_type, :string
  end
end
