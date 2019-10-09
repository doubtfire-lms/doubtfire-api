class AddPlagiarismChecksData < ActiveRecord::Migration[4.2]
  def change
  	add_column :task_definitions, :plagiarism_checks, :string, :limit => 2048
  end
end
