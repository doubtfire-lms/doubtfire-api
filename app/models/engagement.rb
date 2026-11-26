# frozen_string_literal: true

require 'uri'

class Engagement < ApplicationRecord
  include FileHelper
  include MimeCheckHelpers

  # Engagements can only be deleted for a short period after they are created.
  # Staff can delete their own engagements within this window...
  DELETE_WINDOW = 1.hour
  # ... while convenors can delete any engagement in their unit within this window.
  CONVENOR_DELETE_WINDOW = 1.week

  belongs_to :project, optional: false, inverse_of: :engagements
  belongs_to :user, optional: false, inverse_of: :engagements

  has_many :engagement_projects, dependent: :destroy, inverse_of: :engagement
  has_many :additional_projects, through: :engagement_projects, source: :project
  has_many :engagement_comments,
           -> { order(:created_at) },
           dependent: :destroy,
           inverse_of: :engagement

  validates :engagement_type, presence: true, length: { maximum: 255 }
  validates :note, presence: true, length: { maximum: 4095 }
  validates :occurred_at, presence: true
  validates :evidence_url, length: { maximum: 2048, allow_blank: true }
  validates :content_type, inclusion: { in: %w[image pdf], allow_nil: true }
  validate :valid_evidence_url
  validate :single_evidence_source
  validate :consistent_attachment_metadata

  before_validation :normalise_text
  before_destroy :delete_attachment

  # Can this engagement still be deleted, or has the delete window passed?
  def within_delete_window?(window = DELETE_WINDOW)
    created_at.present? && created_at > window.ago
  end

  def attachment?
    content_type.present? && attachment_extension.present?
  end

  def attachment_path
    FileHelper.engagement_attachment_path(self, attachment_extension)
  end

  def attachment_file_name
    "engagement-#{id}#{attachment_extension}"
  end

  def attachment_mime_type
    mime_type(attachment_path)
  end

  def replace_attachment(file_upload, attachment_type)
    delete_attachment
    self.evidence_url = nil
    self.content_type = attachment_type

    if attachment_type == 'image'
      self.attachment_extension =
        if mime_type(file_upload['tempfile'].path).starts_with?('image/gif')
          '.gif'
        else
          '.jpg'
        end
      save!
      image_saved = FileHelper.compress_image_to_dest(file_upload['tempfile'].path, attachment_path)
      raise 'Failed to save engagement image attachment' unless image_saved && File.exist?(attachment_path)
    else
      self.attachment_extension = '.pdf'
      save!
      FileHelper.compress_pdf(file_upload['tempfile'].path)
      FileUtils.mv(file_upload['tempfile'].path, attachment_path)
      raise 'Failed to save engagement PDF attachment' unless File.exist?(attachment_path)
    end

    file_upload['tempfile'].unlink if File.exist?(file_upload['tempfile'].path)
    true
  end

  def remove_attachment
    delete_attachment
    self.content_type = nil
    self.attachment_extension = nil
  end

  private

  def normalise_text
    self.engagement_type = engagement_type&.strip
    self.note = note&.strip
    self.evidence_url = evidence_url&.strip.presence
  end

  def valid_evidence_url
    return if evidence_url.blank?

    uri = URI.parse(evidence_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    errors.add(:evidence_url, 'must be a valid HTTP or HTTPS URL')
  rescue URI::InvalidURIError
    errors.add(:evidence_url, 'must be a valid HTTP or HTTPS URL')
  end

  def single_evidence_source
    return unless evidence_url.present? && (content_type.present? || attachment_extension.present?)

    errors.add(:base, 'An engagement can have either an evidence URL or an attachment, not both')
  end

  def consistent_attachment_metadata
    return if content_type.present? == attachment_extension.present?

    errors.add(:base, 'Attachment content type and extension must both be present')
  end

  def delete_attachment
    FileUtils.rm_f(attachment_path) if attachment_extension.present?
  end
end
