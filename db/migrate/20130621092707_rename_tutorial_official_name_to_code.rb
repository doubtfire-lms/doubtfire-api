class RenameTutorialOfficialNameToCode < ActiveRecord::Migration[4.2]
  def change
    rename_column :tutorials, :official_name, :code
  end
end
