require 'open3'

class OverseerImage < ApplicationRecord
  # Callbacks - methods called are private
  before_destroy :can_destroy?

  has_many :units
  has_many :task_definitions

  # Always add a unique index with uniqueness constraint
  # This is to prevent new records from passing the validations when checked at the same time before being written
  validates :name,  presence: true, uniqueness: true
  validates :tag,   presence: true, uniqueness: true, format: { with: /\A([\w.\-_]+((?::\d+|)(?=\/[a-z0-9._-]+\/[a-z0-9._-]+))|)(?:\/|)([a-z0-9.\-_]+(?:\/[a-z0-9.\-_]+|))(:([\w.\-_]{1,127})|)\z/ }

  enum pulled_image_status: { failed: 0, success: 1 }

  # Pulls overseer image
  def pull_from_docker
    unless valid?
      return false
    end

    #TODO: add global repository ... #{global_registry_setting}#{tag}... so you can add a global registry without it being added to the tag name
    self.last_pulled_date = Time.zone.now
    cmd = "docker pull #{tag}"
    out_text, error_text, exit_status = Open3.capture3(cmd)
    self.pulled_image_text = "#{cmd}\n#{out_text}\n#{error_text}"

    if (exit_status != 0)
      self.pulled_image_status = :failed
    else 
      self.pulled_image_status = :success
    end

    logger.debug self.pulled_image_text

    self.save
  end

  private

  def can_destroy?
    return true if units.count == 0 && task_definitions.count == 0

    errors.add :base, "Cannot delete overseer image with associated units and/or task definitions"
    throw :abort
  end
end
