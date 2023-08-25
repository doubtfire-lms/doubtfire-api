# freeze_string_literal: true

# Turn It In Group Attachment objects track individual template files uploaded
# to assessments in turn it in. These come from task resources for the
# task definition.
class TiiGroupAttachment < ApplicationRecord
  belongs_to :task_definition
  has_many :tii_actions, as: :entity, dependent: :destroy

  before_destroy :delete_attachment

  enum status: {
    created: 0,
    has_id: 1,
    uploaded: 2,
    complete: 3
  }

  delegate :tii_group_id, to: :task_definition

  def status_sym
    status.to_sym
  end

  def self.find_or_create_from_task_definition(task_definition, filename)
    contents = task_definition.read_file_from_resources(filename)
    return nil if contents.nil?

    digest = Digest::SHA1.hexdigest(contents)

    result = TiiGroupAttachment.where(
      task_definition: task_definition,
      filename: filename
    ).first

    unless result.present? && result.file_sha1_digest == digest
      # doesn't exist, or was changed, so create a new attachment
      result = TiiGroupAttachment.create(
        task_definition: task_definition,
        filename: filename,
        status: :created,
        file_sha1_digest: digest
      )

      TiiActionUploadTaskResources.create(
        entity: result
      ).perform
    end

    result
  end

  private

  def delete_attachment
    return unless group_attachment_id.present?

    TiiActionDeleteGroupAttachment.create(
      entity: nil,
      params: {
        group_id: tii_group_id,
        group_attachment_id: group_attachment_id,
        description: "Delete assessment attachment - #{filename} in #{task_definition.abbreviation} for #{task_definition.unit.code}"
      }
    ).perform
  end
end
