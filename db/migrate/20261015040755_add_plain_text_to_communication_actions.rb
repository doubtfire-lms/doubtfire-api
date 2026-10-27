class AddPlainTextToCommunicationActions < ActiveRecord::Migration[8.0]
  def change
    add_column :communication_actions, :plain_text, :boolean, default: false, null: false
  end
end
