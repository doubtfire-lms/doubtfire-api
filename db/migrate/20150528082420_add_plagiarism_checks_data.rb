class AddPlagiarismChecksData < ActiveRecord::Migration
  def change
  	add_column :task_definitions, :plagiarism_checks, :string, :limit => 2048
  end
end
