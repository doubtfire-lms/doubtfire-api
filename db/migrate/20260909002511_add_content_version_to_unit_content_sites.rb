class AddContentVersionToUnitContentSites < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:unit_content_sites, :content_version)

    add_column :unit_content_sites, :content_version, :string, limit: 64
    say 'Run `rails unit_content_sites:extract_all` to populate versions and extract archives.'
  end

  def down
    remove_column :unit_content_sites, :content_version if column_exists?(:unit_content_sites, :content_version)
  end
end
