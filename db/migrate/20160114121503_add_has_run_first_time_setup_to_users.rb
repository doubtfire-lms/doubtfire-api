class AddHasRunFirstTimeSetupToUsers < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :has_run_first_time_setup, :boolean, default: false
  end

  def down
    remove_column :users, :has_run_first_time_setup
  end
end
