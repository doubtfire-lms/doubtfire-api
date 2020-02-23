class UnitExtensionOptions < ActiveRecord::Migration
  def change
    add_column :units, :auto_apply_extension_before_deadline, :boolean, null: false, default: true
  end
end
