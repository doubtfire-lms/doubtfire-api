# freeze_string_literal: true

# Keeps track of actions that are to be performed on TurnItIn. This allows
# all actions to be retried if they fail, and manages this process.
class TiiAction < ApplicationRecord

  enum error_code: {
    task_def_create_group: 0,
    no_user_with_accepted_eula: 1,
    excessive_retries: 2,
    malformed_request: 3,
    authentication_error: 4,
    missing_submission: 5,
    missing_group: 6,
    generation_failed: 7,
    invalid_submission_size_too_large: 8,
    invalid_submission_size_empty: 9,
    existing_submission: 10,
    submission_not_found_when_creating_similarity_report: 11,
    rate_limited: 12,
    service_not_available: 13,
    custom_tii_error: 14
  }

  # Belongs to an entity that is trying to perform an action with turn it in
  # - User: accept eula
  # - TaskDefinition: create group
  # - TiiSubmission: create submission
  # - TiiGroupAttachment: upload attachment
  belongs_to :entity, polymorphic: true, optional: true

  validate :entity_must_be_unique_within_type_on_create, on: :create

  serialize :params, coder: JSON
  serialize :log, coder: JSON

  def description
    'Generic Turnitin Action'
  end

  def perform_async
    TiiActionJob.perform_async(id)
  end

  # Runs the action, and handles any errors that occur
  #
  # @return value returned by running the action, or nil if the action failed
  def perform
    self.error_code = nil if self.retry && error?
    self.custom_error_message = nil

    self.log = [] if self.complete # reset log if complete... and performing again

    self.log << { date: Time.zone.now, message: "Started #{type}" }
    self.last_run = Time.zone.now
    self.retry = false # reset retry flag
    self.log = [] if self.complete # reset log if complete... and performing again
    self.complete = false # reset complete flag

    result = run
    self.log << { date: Time.zone.now, message: "#{type} Ended" }
    save

    result
  rescue StandardError => e
    save_and_log_custom_error e&.to_s

    if Rails.env.development? || Rails.env.test?
      puts e.inspect
    end

    nil
  end

  def error_code_sym
    error_code.to_sym
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
    when :rate_limited
      'Turn It In integration is rate limited at the moment, we will try again later'
    when :service_not_available
      'Turn It In services is not available at the moment, we will try again later'
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

  def save_and_reschedule(reset_retry: true)
    self.retries = 0 if reset_retry
    self.retry = true
    save
  end

  # Save the submission or attachment, resetting the retry count if needed
  def save_and_mark_complete
    self.retries = 0
    self.complete = true

    save!
  end

  # Record that we have completed a part of the action
  # Resets the retry count, and mark the part complete at time
  # to ensure future retries start from the new time.
  def save_progress
    self.retries = 0
    self.complete_at = DateTime.now
    save!
  end

  private

  # Run the action - abstract class to be overridden in child classes
  def run
    raise "SYSTEM ERROR: method missing"
  end

  # Retry the request up to 48 times over 24 hours.
  # The TiiCheckProgressJob will retry any actions that have not been completed
  def retry_request
    self.retries += 1

    last_recorded_complete_time = complete_at || created_at

    if self.retries > 48 && last_recorded_complete_time < DateTime.now - 24.hours
      self.error_code = :excessive_retries
    else
      self.retry = true
    end
  end

  def handle_error(error, codes = [])
    received_error_code = error.is_a?(TCAClient::ApiError) ? error.code : error.error_code
    case received_error_code
    when 400
      self.error_code = :malformed_request
      return
    when 403
      self.error_code = :authentication_error
      return
    when 451
      self.error_cde = :no_user_with_accepted_eula
      return
    when 429 # is not currently used by TCA
      self.error_code = :rate_limited
      retry_request
      return
    when 500, 503, 504 # service unavailable, gateway timeout
      self.error_code = :service_not_available
      retry_request
      return
    when 0
      self.error_code = :custom_tii_error
      self.custom_error_message = error.message
      return
    end

    return if codes.find do |check|
                next unless received_error_code == check[:code]

                self.error_code = check.key?(:symbol) ? check[:symbol] : :custom_tii_error
                self.custom_error_message = check[:message] if check.key?(:message)
                return check
              end.present?

    # If we get here, we have an error that we don't know how to handle
    self.error_code = :custom_tii_error
    self.custom_error_message = error.to_s
  ensure
    log_error
    save
  end

  def save_and_log_custom_error(message)
    self.error_code = :custom_tii_error
    self.custom_error_message = message
    self.complete = false
    log_error
    save

    logger.error message
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
      raise TCAClient::ApiError, code: 0, message: "Turn It In not functiona: #{description}"
    end
    if TurnItIn.rate_limited?
      raise TCAClient::ApiError, code: 429, message: "Turn It In rate limited: #{description}"
    end

    self.log << { date: Time.zone.now, message: description }

    block.call
  rescue TCAClient::ApiError => e
    TurnItIn.handle_tii_error(description, e) # set global errors if needed
    handle_error(e, codes)
    save # Error is logged in exec_tca_call

    nil
  end

  def entity_must_be_unique_within_type_on_create
    # Unique if none already exist
    return if entity.nil? || self.class.where(entity_id: entity_id, entity_type: entity_type, type: type).count == 0

    errors.add(:entity, 'must be unique within the action')
  end
end
