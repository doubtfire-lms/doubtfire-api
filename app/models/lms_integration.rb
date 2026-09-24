# frozen_string_literal: true

class LmsIntegration < ApplicationRecord
  SOURCES = %w[lti].freeze
  # Nights an outage can keep scheduled syncs failing before they are turned off
  AUTO_SYNC_GRACE_DAYS = 3
  # LTI service statuses for problems with the LMS course or link, rather than an outage
  CONVENOR_ERROR_STATUSES = [404, 409, 422].freeze

  belongs_to :unit
  has_many :lms_group_mappings, dependent: :destroy

  validates :source, inclusion: { in: SOURCES }
  validates :assignment_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :unit_id, uniqueness: true

  scope :auto_syncing, -> { where(auto_sync_students: true).or(where(auto_sync_extensions: true)) }

  before_save :clear_auto_sync_failure, if: :auto_sync_turned_on?

  # Errors a convenor has to fix. Anything else could be an outage, so the next night's sync retries it.
  def self.convenor_error?(error)
    return true if error.is_a?(LmsIntegrationValidator::ValidationError)

    server_error = [error, error.cause].find { |cause| cause.is_a?(LtiServer::Error) }
    return CONVENOR_ERROR_STATUSES.include?(server_error.status) if server_error

    error.is_a?(LtiCourseDataSource::Error)
  end

  def self.data_source_for(unit)
    source = unit.lms_integration&.source.presence || 'lti'
    case source
    when 'lti'
      LtiCourseDataSource.new(unit)
    end
  end

  def data_source
    LmsIntegration.data_source_for(unit)
  end

  def mark_unvalidated!
    update!(validated: false, validated_at: nil) if validated? || validated_at.present?
  end

  def auto_sync_failed!(sync, error)
    if LmsIntegration.convenor_error?(error)
      turn_off_auto_sync!(sync, error, outage: false)
    else
      record_auto_sync_outage!(sync, error)
    end
  end

  def record_auto_sync_outage!(sync, error)
    with_lock do
      self.auto_sync_failing_since ||= Time.current
      self.auto_sync_last_error = error.message
      save!
    end
    turn_off_auto_sync!(sync, error, outage: true) if auto_sync_turn_off_date <= Time.zone.today
  end

  # Once auto sync is off, the failure stays visible until a convenor turns it back on
  def auto_sync_succeeded!
    with_lock do
      update!(auto_sync_failing_since: nil, auto_sync_last_error: nil) if auto_sync_students? || auto_sync_extensions?
    end
  end

  def auto_sync_turn_off_date
    auto_sync_failing_since&.to_date&.advance(days: AUTO_SYNC_GRACE_DAYS)
  end

  private

  def auto_sync_turned_on?
    will_save_change_to_auto_sync_students?(to: true) || will_save_change_to_auto_sync_extensions?(to: true)
  end

  def clear_auto_sync_failure
    self.auto_sync_failing_since = nil
    self.auto_sync_last_error = nil
  end

  # Only the failure that turns auto sync off emails the main convenor
  def turn_off_auto_sync!(sync, error, outage:)
    turned_off = with_lock do
      settings = %i[auto_sync_students auto_sync_extensions].select { |setting| self[setting] }
      if settings.any?
        assign_attributes(settings.index_with(false))
        self.auto_sync_last_error = error.message
        save!
      end
      settings
    end
    return if turned_off.empty?

    begin
      LmsIntegrationMailer.auto_sync_failed(self, sync, error, turned_off, outage).deliver_now
    rescue StandardError => e
      Rails.logger.error "Failed to email the LMS auto sync failure for unit #{unit_id}: #{e.message}"
    end
  end
end
