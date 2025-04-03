class AddMissingTimestamps < ActiveRecord::Migration[8.0]
  def change
    add_timestamps :auth_tokens
    add_timestamps :breaks
    add_timestamps :campuses
    add_timestamps :learning_outcomes
    add_timestamps :teaching_periods
    add_timestamps :test_attempts
    add_timestamps :webcal_unit_exclusions
    add_timestamps :webcals
  end
end
