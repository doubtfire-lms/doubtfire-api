class CreateBadges < ActiveRecord::Migration
  def change
    create_table :badges do |t|
      t.string :name
      t.text :description
      t.string :large_image_url
      t.string :small_image_url
      t.references :sub_task_definition

      t.timestamps
    end
  end
end
