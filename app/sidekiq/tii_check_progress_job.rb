# frozen_string_literal: true

# All TII actions will halt retries on errors that indicate throttling.
# This job checks for any outstanding turn it in actions, and reties these
# after an extended period.
class TiiCheckProgressJob
  include Sidekiq::Job

  def perform
    check_awaiting_user_eula_accept
  end

  # Check users awaiting eula accept and process their eula acceptance
  def check_awaiting_user_eula_accept
    # Get users that have accepted eula but this has not been confirmed
    users_waiting = User.where(tii_eula_version_confirmed: false).where('tii_eula_date < :date AND (last_eula_retry IS NULL OR last_eula_retry < :date)', date: DateTime.now - 30.minutes)

    # Try to update eula for each of these users
    users_waiting.each do |user|
      TurnItIn.accept_eula(user)
    end
  end
end
