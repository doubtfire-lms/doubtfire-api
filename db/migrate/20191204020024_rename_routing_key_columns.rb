class RenameRoutingKeyColumns < ActiveRecord::Migration
  def change
    rename_column :task_definitions, :routing_key, :docker_image_name_tag
    rename_column :units, :routing_key, :docker_image_name_tag
  end
end
