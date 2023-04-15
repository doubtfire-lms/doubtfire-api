module TurnItInRequestHelper
  def error_message
    return nil if error_code.nil?

    case error_code.to_sym
    when :no_user_with_accepted_eula
      'No user has accepted the TII EULA'
    when :excessive_retries
      'Failed due to excessive retries'
    when :malformed_request
      'Request is malformed or missing required data'
    when :authentication_error
      'Authenticated with Turn It In failed - adjust configuration'
    when :missing_submission
      'Submission not found in downloading similarity pdf'
    when :generation_failed
      'PDF failed to generate, status FAILED'
    when :invalid_submission_size_too_large
      'Invalid submission file size, Submission file must be <= to 100 MB'
    when :invalid_submission_size_empty
      'Invalid submission file size, Submission file must be > than 0 MB'
    when :existing_submission
      'Submission already exists'
    when :submission_not_found_when_creating_similarity_report
      'Submission not found in creating similarity report'
    else
      self.custom_error_message
    end
  end

  def error?
    error_code.present?
  end

  def handle_error(error, codes = [])
    case error.is_a?(TCAClient::ApiError) ? error.code : error.error_code
    when 400
      self.error_code = :malformed_request
      save
      return
    when 403
      self.error_code = :authentication_error
      save
      return
    when 429
      Doubtfire::Application.config.logger.error "Request has been rejected due to rate limiting - tii_submission #{id}"
      retry_request
      return
    when 503, 504 # service unavailable, gateway timeout
      retry_request
      return
    when 0
      self.error_code = :custom_tii_error
      self.custom_error_message = error.message
      save
    end

    codes.each do |check|
      next unless error.error_code == check[:code]

      self.error_code = check.key?(:symbol) ? check[:symbol] : :custom_tii_error
      self.custom_error_message = check[:message] if check.key?(:message)
      save
      break
    end
  end

  # Save the submission or attachment, resetting the retry count if needed
  def save_and_reset_retry
    unless self.next_process_update_at.nil?
      self.retries = 0
      self.next_process_update_at = nil
    end

    save
  end

  def retry_request
    self.retries += 1
    if self.retries > 10
      self.error_code = :excessive_retries
      Doubtfire::Application.config.logger.error "Error with tii submission: #{id} excessive retries"
    else
      self.next_process_update_at = Time.zone.now + 30.minutes
    end

    save
  end
end
