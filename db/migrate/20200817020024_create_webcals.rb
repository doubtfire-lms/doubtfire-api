class CreateWebcals < ActiveRecord::Migration
  def change
    create_table(:webcals, id: false) do |t|

      # Expected to be a 36 character GUID (string). Not defined as a primary key here because Rails doesn't dump the
      # definition of the primary key to schema.rb even when the type is explicitly specified via create_table.
      t.string     :id, null: false, limit: 36, index: { unique: true }

      t.boolean    :include_start_dates, null: false, default: false
      t.references :user, foreign_key: true, index: { unique: true }
    end
  end
end
