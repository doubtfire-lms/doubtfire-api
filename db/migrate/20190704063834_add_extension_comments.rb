class AddExtensionComments < ActiveRecord::Migration
  def change
    add_column :task_comments, :date_extension_assessed, :datetime
    add_column :task_comments, :extension_granted, :boolean
    add_column :task_comments, :assessor_id, :integer
  end
end
