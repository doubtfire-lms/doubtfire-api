class AddPrimaryKeyToCrr < ActiveRecord::Migration
  def change
    add_column :comments_read_receipts, :id, :primary_key
  end
end
