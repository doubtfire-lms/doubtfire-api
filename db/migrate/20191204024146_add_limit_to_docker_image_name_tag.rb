class AddLimitToDockerImageNameTag < ActiveRecord::Migration
  def change
    change_column :task_definitions, :docker_image_name_tag, :string, :limit => 255
    change_column :units, :docker_image_name_tag, :string, :limit => 255
  end
end
