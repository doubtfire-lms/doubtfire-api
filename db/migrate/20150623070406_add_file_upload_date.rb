class AddFileUploadDate < ActiveRecord::Migration[4.2]
  def change
  	add_column :tasks, :file_uploaded_at, :datetime
  end
end
