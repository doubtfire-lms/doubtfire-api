class AddObserverToUnitRoles < ActiveRecord::Migration[7.1]
  def change
    add_column :unit_roles, :observer, :boolean, default: false
  end
end
