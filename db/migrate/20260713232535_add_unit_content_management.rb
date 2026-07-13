class AddUnitContentManagement < ActiveRecord::Migration[8.0]
  def change
    create_table :unit_content_sites do |t|
      t.references :unit, null: false
      t.string :name, null: false
      t.string :original_filename, null: false
      t.string :archive_path, null: false
      t.string :root_dir, null: false, default: '/'
      t.boolean :is_main, null: false, default: false

      t.timestamps
    end

    add_index :unit_content_sites, [:unit_id, :name], unique: true

    create_table :unit_content_links do |t|
      t.references :unit, null: false
      t.references :unit_content_site, null: false
      t.string :context_type, null: false
      t.string :context_key, null: false
      t.string :route, null: false, default: '/'

      t.timestamps
    end

    add_index :unit_content_links,
              [:unit_id, :context_type, :context_key],
              unique: true,
              name: 'index_unit_content_links_on_context'
  end
end
