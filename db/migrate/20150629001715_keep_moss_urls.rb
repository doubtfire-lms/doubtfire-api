class KeepMossUrls < ActiveRecord::Migration
  def change
  	add_column :task_definitions, :plagiarism_report_url, :string
  	add_column :task_definitions, :plagiarism_updated, :boolean, :default => false
  	add_column :task_definitions, :plagiarism_warn_pct, :integer, :default => 50
  	add_column :plagiarism_match_links, :plagiarism_report_url, :string
  end
end
