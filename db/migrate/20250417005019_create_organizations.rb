class CreateOrganizations < ActiveRecord::Migration[7.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :description, limit: 1200
      t.string :email
      t.boolean :is_enabled, default: true

      t.timestamps
    end
      add_index :organizations, :name, unique: true

    create_table :user_organizations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_organizations, [:user_id, :organization_id], unique: true
  end
end
