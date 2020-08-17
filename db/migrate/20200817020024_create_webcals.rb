class CreateWebcals < ActiveRecord::Migration
  def change
    create_table(:webcals, id: :string) do |t|
      t.boolean    :include_start_dates, null: false, default: false
      t.references :user, foreign_key: true, index: { unique: true }
    end
  end
end
