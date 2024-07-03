class AddScormExtensions < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :scorm_extensions, :integer, null: false, default: 0
  end
end
