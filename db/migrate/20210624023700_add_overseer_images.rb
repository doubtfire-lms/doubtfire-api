class AddOverseerImages < ActiveRecord::Migration
  def change
    create_table :overseer_images do |t|
      t.string      :name,          null: false
      t.string      :tag,           null: false
      t.timestamps                  null: false
    end

    remove_column :units, :docker_image_name_tag, :string
    remove_column :task_definitions, :docker_image_name_tag, :string

    add_column :units, :overseer_image_id, :integer
    add_column :task_definitions, :overseer_image_id, :integer
    
    add_index :units, :overseer_image_id
    add_index :task_definitions, :overseer_image_id
  end
end
