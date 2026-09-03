class TutorNote < ApplicationRecord
  belongs_to :unit_role
  belongs_to :user
  belongs_to :task, optional: true
  belongs_to :reply_to, class_name: "TutorNote", optional: true
  has_many :notifications, dependent: :destroy

  def notification_for(recipient)
    notifications.detect { |notification| notification.recipient_id == recipient.id }
  end

  # Falls back to read_by_unit_role for notes with no notification, either older
  # ones or a recipient who has moderation notifications switched off.
  def requires_read_by?(recipient)
    notification = notification_for(recipient)
    return notification.read_at.nil? unless notification.nil?
    return false if user_id == recipient.id

    unit_role.user_id == recipient.id && !read_by_unit_role
  end

  def task_definition_id
    task&.task_definition&.id
  end

  def project_id
    task&.project&.id
  end
end
