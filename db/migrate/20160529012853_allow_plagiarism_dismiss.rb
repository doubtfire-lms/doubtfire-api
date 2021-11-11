class AllowPlagiarismDismiss < ActiveRecord::Migration[4.2]
  def change
      add_column :plagiarism_match_links, :dismissed, :boolean, default: false
  end
end
