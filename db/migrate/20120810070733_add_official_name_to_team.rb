class AddOfficialNameToTeam < ActiveRecord::Migration[4.2]
  def change
    add_column :teams, :official_name, :string
  end
end
