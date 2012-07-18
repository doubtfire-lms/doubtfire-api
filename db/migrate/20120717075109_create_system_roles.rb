class CreateSystemRoles < ActiveRecord::Migration
  def change
    create_table :system_roles do |t|
    	t.string :name
    end
  end
end
