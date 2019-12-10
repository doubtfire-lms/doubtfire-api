class MakeLoginIdNullable < ActiveRecord::Migration[4.2]
  def change
    change_column :users, :login_id, :string, null: true, default: nil
  end
end
