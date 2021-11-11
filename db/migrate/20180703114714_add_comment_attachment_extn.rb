class AddCommentAttachmentExtn < ActiveRecord::Migration[4.2]
  def change
    add_column :task_comments, :attachment_extension, :string
  end
end
