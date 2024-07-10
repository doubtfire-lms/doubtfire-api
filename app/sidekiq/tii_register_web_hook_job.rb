# frozen_string_literal: true

# Check and make sure we are registered with TurnItIn for
# all web hook callbacks
class TiiRegisterWebHookJob
  include Sidekiq::Job

  def perform
    return unless TurnItIn.enabled?

    (TiiActionRegisterWebhook.last || TiiActionRegisterWebhook.create).perform
  end
end
