class AddPrimaryKeyToCrr < ActiveRecord::Migration[4.2]
  def change
    add_column :comments_read_receipts, :id, :primary_key
  end
end
