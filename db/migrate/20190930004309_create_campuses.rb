class CreateCampuses < ActiveRecord::Migration[4.2]
  def change
    create_table :campuses do |t|
      t.string        :name,                null: false
      t.integer       :mode,                null: false
    end
  end
end
