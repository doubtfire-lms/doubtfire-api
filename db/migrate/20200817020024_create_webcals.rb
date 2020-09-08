class CreateWebcals < ActiveRecord::Migration
  def change
    create_table :webcals do |t|

      # Expected to be a 36 character GUID (string).
      t.string     :guid, null: false, limit: 36, index: { unique: true }

      t.boolean    :include_start_dates, null: false, default: false
      t.references :user, foreign_key: true, index: { unique: true }
    end
  end
end
