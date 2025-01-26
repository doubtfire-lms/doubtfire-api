# frozen_string_literal: true

require 'tempfile'

class TaskComment < ApplicationRecord
  include MimeCheckHelpers
  include TimeoutHelper
  include FileHelper
  include AuthorisationHelpers

  belongs_to :task, optional: false # Foreign key
  belongs_to :user, optional: false
  has_one :unit, through: :task
  has_one :project, through: :task

  belongs_to :recipient, class_name: 'User', optional: false

  has_many :comments_read_receipts, class_name: 'CommentsReadReceipts', dependent: :destroy, inverse_of: :task_comment

  # Can optionally be a reply to a comment
  belongs_to :task_comment, optional: true

  # Can be a comment for different types of entities e.g. Test Attempt, Overseer Assessment
  belongs_to :commentable, polymorphic: true, optional: true

  validates :task, presence: true
  validates :user, presence: true
  validates :recipient, presence: true
  validates :comment, length: { minimum: 0, maximum: 4095, allow_blank: true }
  validate :valid_reply_to?, on: :create

  # After create, mark as read by user creating
  after_create do
    mark_as_read(self.user)
  end

  # Delete action - before dependent association
  before_destroy :delete_associated_files

  def valid_reply_to?
    if reply_to_id.present?
      originalTaskComment = TaskComment.find(reply_to_id)
      replyProject = originalTaskComment.project
      errors.add(:task_comment, "Not a reply to a valid task comment") if originalTaskComment.blank?
      errors.add(:task_comment, "Original comment is not in this task") if task.all_comments.find(reply_to_id).blank?
      errors.add(:task_comment, "Not authorised to reply to comment") unless authorise?(user, originalTaskComment.project, :get) || (task.group_task? && task.group.role_for(user) != nil)
    end
  end

  def delete_associated_files
    FileUtils.rm_f attachment_path
  end

  def serialize(user)
    {
      id: self.id,
      comment: self.comment,
      has_attachment: ["audio", "image", "pdf"].include?(self.content_type),
      type: self.content_type || "text",
      is_new: self.new_for?(user),
      reply_to_id: self.reply_to_id,
      author: {
        id: self.user.id,
        first_name: self.user.first_name,
        last_name: self.user.last_name,
        email: self.user.email
      },
      recipient: {
        id: self.recipient.id,
        first_name: self.recipient.first_name,
        last_name: self.recipient.last_name,
        email: self.recipient.email
      },
      created_at: self.created_at,
      recipient_read_time: self.time_read_by(self.recipient),
    }
  end

  def create_comment_read_receipt_entry(user)
    comment_read_receipt = CommentsReadReceipts.find_or_create_by(user: user, task_comment: self)
  end

  def comment
    return 'audio comment' if content_type == 'audio'
    return 'image comment' if content_type == 'image'
    return 'pdf document' if content_type == 'pdf'
    return 'discussion comment' if content_type == 'discussion'

    super
  end

  def attachment_path
    FileHelper.comment_attachment_path(self, attachment_extension)
  end

  def attachment_file_name
    "comment-#{id}#{attachment_extension}"
  end

  def add_attachment(file_upload)
    if content_type == 'audio'
      # On upload all audio comments are converted to wav
      temp = Tempfile.new(['comment', '.wav'])
      return false unless process_audio(file_upload["tempfile"].path, temp.path)

      self.attachment_extension = '.wav'
      save
      FileUtils.mv temp.path, attachment_path
    elsif content_type == 'image'
      self.attachment_extension = if mime_type(file_upload["tempfile"].path).starts_with?('image/gif')
                                    '.gif'
                                  else
                                    '.jpg'
                                  end
      save
      FileHelper.compress_image_to_dest(file_upload["tempfile"].path, attachment_path)
    else
      self.attachment_extension = '.pdf'
      save
      FileHelper.compress_pdf(file_upload["tempfile"].path)
      FileUtils.mv file_upload["tempfile"].path, attachment_path
    end

    file_upload["tempfile"].unlink

    true
  end

  def attachment_mime_type
    if attachment_extension == '.wav'
      'audio/wav; charset:binary'
    else
      mime_type(attachment_path)
    end
  end

  def remove_comment_read_entry(user)
    CommentsReadReceipts.delete_all(user: user, task_comment: self)
  end

  def mark_as_read(user, unit = self.unit)
    return if read_by?(user) # avoid propagating if not needed

    if user == project.tutor_for(task.task_definition)
      unit.staff.each do |staff_member|
        create_comment_read_receipt_entry(staff_member.user)
      end
    else
      create_comment_read_receipt_entry(user)
    end
  end

  def mark_as_unread(user)
    remove_comment_read_entry(user)
  end

  def new_for?(user)
    !read_by? user
  end

  def read_by?(user)
    CommentsReadReceipts.find_by(user: user, task_comment: self).present?
  end

  def time_read_by(user)
    read_reciept = CommentsReadReceipts.find_by(user: user, task_comment: self)
    read_reciept&.created_at
  end
end
