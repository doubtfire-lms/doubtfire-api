class AddTiiLinkFilename < ActiveRecord::Migration[7.0]
  def change
    add_column :plagiarism_match_links, :kind, :string, default: 'moss'
    change_column_default :plagiarism_match_links, :kind, from: 'moss', to: nil
  end
end
