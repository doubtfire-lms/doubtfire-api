class AddAttachmentInComments < ActiveRecord::Migration
  def change
    add_attachment :task_comments, :attachment
  end
end
