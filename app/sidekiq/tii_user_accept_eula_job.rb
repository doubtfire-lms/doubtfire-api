# Accept the turn it in eula for a user
class TiiUserAcceptEulaJob
  include Sidekiq::Job

  # Make the call to turn it in to indicate the user accepted the eula
  #
  # @param user_id [Integer] the id of the user who accepted the eula
  def perform(user_id)
    user = User.find(user_id)

    unless user.tii_eula_version_confirmed || TurnItIn.accept_eula(user)
      if user.tii_eula_retry && user.tii_eula_date.present? && user.tii_eula_date < DateTime.now + 1.day
        # If the eula was not accepted, then retry the job
        # for at most one day
        TiiUserAcceptEulaJob.perform_in(30.minutes, user_id)
      else
        Doubtfire::Application.config.logger.error "TII failed. accept eula for user #{user.id}. Timeout after 1 day of retrying"
        user.update(tii_eula_retry: false)
      end
    end
  end
end
