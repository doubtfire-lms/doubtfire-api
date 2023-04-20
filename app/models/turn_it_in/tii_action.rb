# freeze_string_literal: true

# Keeps track of actions that are to be performed on TurnItIn. This allows
# all actions to be retried if they fail, and manages this process.
class TiiAction < ApplicationRecord

  enum action: {
    task_def_create_group: 0
  }

  # Belongs to an entity that is trying to perform an action with turn it in
  # - User: accept eula
  # - TaskDefinition: create group
  # - TiiSubmission: create submission
  # - TiiGroupAttachment: upload attachment
  belongs_to :entity, polymorphic: true

  serialize :params, JSON
  serialize :log, JSON

  def perform_async
    TiiActionJob.perform_async(id)
  end

  # Runs the action, and handles any errors that occur
  def perform
    self.log << { date: Time.zone.now, message: "Started" }
    run
    self.log << { date: Time.zone.now, message: "Ended" }
  rescue StandardError => e
    save_and_log_custom_error e&.to_s
  end

  # Use the error code or the custom error message to return the error message (or nil if no error)
  #
  # @return [String] the error message or nil if no error
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
    when :missing_group
      'Group not found in downloading similarity pdf'
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

  # Check if there is an error
  #
  # @return [Boolean] true if there is an error, false otherwise
  def error?
    error_code.present?
  end

  def handle_error(error, codes = [])
    case error.is_a?(TCAClient::ApiError) ? error.code : error.error_code
    when 400
      self.error_code = :malformed_request
      return
    when 403
      self.error_code = :authentication_error
      return
    when 429
      logger.error "Request has been rejected due to rate limiting - tii_submission #{id}"
      retry_request
      return
    when 503, 504 # service unavailable, gateway timeout
      retry_request
      return
    when 0
      self.error_code = :custom_tii_error
      self.custom_error_message = error.message
      return
    end

    codes.each do |check|
      next unless error.error_code == check[:code]

      self.error_code = check.key?(:symbol) ? check[:symbol] : :custom_tii_error
      self.custom_error_message = check[:message] if check.key?(:message)
      break
    end
  ensure
    save
    log_error
  end

  # Save the submission or attachment, resetting the retry count if needed
  def save_and_reset_retry(success: true)
    # if we had to retry...
    unless self.next_process_update_at.nil?
      self.retries = 0
      self.next_process_update_at = nil
    end

    self.complete = success if success

    save
  end

  private

  # Run the action - abstract class to be overridden in child classes
  def run
    raise "SYSTEM ERROR: method missing"
  end

  # Retry the request in 30 minutes, up to 10 times
  def retry_request
    self.retries += 1
    if self.retries > 10
      self.error_code = :excessive_retries
      Doubtfire::Application.config.logger.error "Error with tii action: #{action} #{id} excessive retries"
    else
      self.next_process_update_at = Time.zone.now + 30.minutes
    end
  end

  def save_and_log_custom_error(message)
    self.error_code = :custom_tii_error
    self.custom_error_message = message
    save

    log_error
  end

  def log_error
    self.log << { date: Time.zone.now, message: error_message }
  end

  # Run a call to TCA, handling any errors that occur
  #
  # @param description [String] the description of the action that is being performed
  # @param block [Proc] the block that will be called to perform the call
  def exec_tca_call(description, codes = [], &block)
    unless TurnItIn.functional?
      logger.error "TII failed. #{description}. Turn It In not functional"
      raise TCAClient::ApiError, code: 0, message: "Turn It In not functional"
    end
    if TurnItIn.rate_limited?
      logger.error "TII failed. #{description}. Turn It In is rate limited"
      raise TCAClient::ApiError, code: 429, message: "Turn It In rate limited"
    end

    block.call
  rescue TCAClient::ApiError => e
    TurnItIn.handle_tii_error(description, e) # set global errors if needed
    handle_error(e, codes)
    raise
  end
end
