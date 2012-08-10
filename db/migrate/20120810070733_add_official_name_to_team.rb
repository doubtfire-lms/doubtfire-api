class AddOfficialNameToTeam < ActiveRecord::Migration
  def change
    add_column :teams, :official_name, :string
  end
end
