class CreateSpecialization < ActiveRecord::Migration[7.1]
  def change
    create_table :specializations do |t|
      t.string :specialization

      t.timestamps
    end
  end
end
