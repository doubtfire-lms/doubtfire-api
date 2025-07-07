class AddJplag < ActiveRecord::Migration[8.0]
  def change
    rename_column :task_definitions, :moss_language, :similarity_language
  end
end
