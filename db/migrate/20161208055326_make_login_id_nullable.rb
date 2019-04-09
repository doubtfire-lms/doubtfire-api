class MakeLoginIdNullable < ActiveRecord::Migration
  def change
    change_column :users, :login_id, :string, null: true, default: nil
  end
end
