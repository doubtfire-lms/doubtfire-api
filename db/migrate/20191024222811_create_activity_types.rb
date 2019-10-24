class CreateActivityTypes < ActiveRecord::Migration
  def change
    create_table :activity_types do |t|
      t.string      :name,          null: false
      t.string      :abbreviation,  null: false
      t.timestamps                  null: false
    end
  end
end
