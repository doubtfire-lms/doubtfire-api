class AddColumnsToOverseerImages < ActiveRecord::Migration[7.0]
  def change
    add_column :overseer_images, :pulled_image_text, :text
    add_column :overseer_images, :pulled_image_status, :integer
    add_column :overseer_images, :last_pulled_date, :datetime
  end
end
