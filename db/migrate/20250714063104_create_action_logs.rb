class CreateActionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :action_logs do |t|
      t.references :user
      t.string :name
      t.json :properties

      t.timestamps
    end
  end
end
