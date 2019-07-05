class AddResponseToExtensionRequest < ActiveRecord::Migration
  def change
    add_column :task_comments, :extension_response, :string
  end
end
