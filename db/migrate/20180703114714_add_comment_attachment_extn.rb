class AddCommentAttachmentExtn < ActiveRecord::Migration
  def change
    add_column :task_comments, :attachment_extension, :string
  end
end
