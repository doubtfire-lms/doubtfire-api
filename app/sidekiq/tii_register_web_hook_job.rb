# frozen_string_literal: true

# Check and make sure we are registered with TurnItIn for
# all web hook callbacks
class TiiRegisterWebHookJob
  include Sidekiq::Job

  def perform
    TurnItIn.register_webhook if need_to_register_webhook?
  end

  def need_to_register_webhook?
    # Get all webhooks
    webhooks = TurnItIn.list_all_webhooks

    # Check if we are registered
    webhooks.each do |webhook|
      return false if webhook.url == TurnItIn.webhook_url
    end

    # If we are not registered, return true
    true
  end
end
