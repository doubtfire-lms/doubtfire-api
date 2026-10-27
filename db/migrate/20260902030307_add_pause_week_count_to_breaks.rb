class AddPauseWeekCountToBreaks < ActiveRecord::Migration[8.0]
  def up
    # Defaults to true to preserve the existing behaviour, where every break
    # pauses the teaching period week count.
    add_column :breaks, :pause_week_count, :boolean, default: true, null: false

    # Only whole week breaks can pause the week count - clear the flag on any
    # break that is not a multiple of 7 days so existing records stay valid.
    execute 'UPDATE breaks SET pause_week_count = FALSE WHERE number_of_days % 7 <> 0'
  end

  def down
    remove_column :breaks, :pause_week_count
  end
end
