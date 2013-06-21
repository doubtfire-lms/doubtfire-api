class RenameTutorialOfficialNameToCode < ActiveRecord::Migration
  def change
    rename_column :tutorials, :official_name, :code
  end
end
