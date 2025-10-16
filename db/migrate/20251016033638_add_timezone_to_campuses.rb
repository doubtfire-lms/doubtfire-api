class AddTimezoneToCampuses < ActiveRecord::Migration[8.0]
  def change
    add_column :campuses, :timezone, :string
  end
end
