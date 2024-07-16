# frozen_string_literal: true

# All TII actions will halt retries on errors that indicate throttling.
# This job checks for any outstanding turn it in actions, and reties these
# after an extended period.
class TiiCheckProgressJob
  include Sidekiq::Job

  def perform
    return unless TurnItIn.enabled?

    TurnItIn.check_and_retry_submissions_with_updated_eula

    run_waiting_actions
    TurnItIn.check_and_update_eula
    TurnItIn.check_and_update_features
  end

  def run_waiting_actions
    # Get the actions waiting to retry, where last run is more than 30 minutes ago, and run them
    TiiAction.where(retry: true, complete: false)
             .where('(last_run IS NULL AND created_at < :date) OR last_run < :date', date: DateTime.now - 30.minutes)
             .find_each do |action|
      action.perform

      # Stop if the service is not available
      break if action.error_code == :service_not_available

      # Sleep to ensure requests are performed at a rate of well below 100 per minute
      sleep(2)
    end
  end
end
