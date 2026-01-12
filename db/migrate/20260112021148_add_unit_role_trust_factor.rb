class AddUnitRoleTrustFactor < ActiveRecord::Migration[8.0]
  def change
    add_column :unit_roles, :trust_factor, :integer, default: 50, null: false
  end
end
