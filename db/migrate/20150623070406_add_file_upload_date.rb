class AddFileUploadDate < ActiveRecord::Migration
  def change
  	add_column :tasks, :file_uploaded_at, :datetime
  end
end
