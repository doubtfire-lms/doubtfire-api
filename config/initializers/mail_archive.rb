# Keeps a copy of each delivered email in ONTRACK_MAIL_ARCHIVE_DIR, in the same format as the :file delivery method.
module MailArchiveObserver
  def self.location
    ENV.fetch('ONTRACK_MAIL_ARCHIVE_DIR', nil).presence
  end

  def self.delivered_email(message)
    Mail::FileDelivery.new(location: location).deliver!(message)
  rescue StandardError => e
    # Never fail the caller: a raised error would make jobs retry and resend the email.
    Rails.logger.error "Failed to archive email #{message.message_id}: #{e.message}"
  end
end

ActiveSupport.on_load(:action_mailer) { register_observer(MailArchiveObserver) } if MailArchiveObserver.location
