class AllowPlagiarismDismiss < ActiveRecord::Migration
  def change
      add_column :plagiarism_match_links, :dismissed, :boolean, default: false
  end
end
