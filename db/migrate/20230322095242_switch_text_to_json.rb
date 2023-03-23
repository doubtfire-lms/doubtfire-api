class SwitchTextToJson < ActiveRecord::Migration[7.0]
  def up
    change_column :task_definitions, :upload_requirements, :json, using: 'CAST(value AS JSON)', collation: nil
    change_column :task_definitions, :plagiarism_checks, :json, using: 'CAST(value AS JSON)', collation: nil
  end

  def down
    change_column :task_definitions, :upload_requirements, :text
    change_column :task_definitions, :plagiarism_checks, :text
  end
end
