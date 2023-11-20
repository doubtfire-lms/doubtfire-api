# frozen_string_literal: true

# All TII actions will halt retries on errors that indicate throttling.
# This job checks for any outstanding turn it in actions, and reties these
# after an extended period.
class TiiCheckProgressJob
  include Sidekiq::Job

  def perform
    run_waiting_actions
    check_update_eula
  end

  # Make sure we have the latest eula version
  def check_update_eula
    last_eula_check = TiiActionFetchEula.last&.last_run

    run = !Rails.cache.exist?('tii.eula_version') ||
          last_eula_check.nil? ||
          last_eula_check < DateTime.now - 1.day

    # Get or create the
    (TiiActionFetchEula.last || TiiActionFetchEula.create).perform if run
  end

  def run_waiting_actions
    # Get the actions waiting to retry, where last run is more than 30 minutes ago, and run them
    TiiAction.where(retry: true, complete: false)
             .where('(last_run IS NULL AND created_at < :date) OR last_run < :date', date: DateTime.now - 30.minutes)
             .each(&:perform)
  end
end
