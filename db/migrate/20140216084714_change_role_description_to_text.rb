class ChangeRoleDescriptionToText < ActiveRecord::Migration[4.2]
  def change
    change_column :roles, :description, :text
  end
end
