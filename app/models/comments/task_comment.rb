# frozen_string_literal: true

require 'tempfile'

class TaskComment < ApplicationRecord
  include MimeCheckHelpers
  include TimeoutHelper
  include FileHelper
  include AuthorisationHelpers

  enum :attention_audience, { none: 0, student: 1, staff: 2 }, prefix: :attention

  belongs_to :task, optional: false # Foreign key
  belongs_to :user, optional: false
  has_one :unit, through: :task
  has_one :project, through: :task

  belongs_to :recipient, class_name: 'User', optional: false

  has_many :comments_read_receipts, class_name: 'CommentsReadReceipts', dependent: :destroy, inverse_of: :task_comment
  has_many :comment_read_cursors,
           foreign_key: :last_read_comment_id,
           inverse_of: :last_read_comment,
           dependent: :restrict_with_exception

  # Can optionally be a reply to a comment
  belongs_to :task_comment, optional: true

  # Can be a comment for different types of entities e.g. Test Attempt, Overseer Assessment
  belongs_to :commentable, polymorphic: true, optional: true

  validates :task, presence: true
  validates :user, presence: true
  validates :recipient, presence: true
  validates :comment, length: { minimum: 0, maximum: 4095, allow_blank: true }
  validate :valid_reply_to?, on: :create

  before_validation :set_default_attention_audience, on: :create

  # After create, mark as read by user creating
  after_create do
    mark_as_read(self.user)
  end

  # Delete action - before dependent association
  before_destroy :rewind_comment_read_cursors, prepend: true
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

  def advance_read_cursor(user)
    CommentReadCursor.advance(task: task, user: user, comment: self)
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
    cursor = CommentReadCursor.find_by(task_id: task_id, user_id: user.id)
    return if cursor.nil? || cursor.last_read_comment_id < id

    previous_comment_id = TaskComment
                          .where(task_id: task_id)
                          .where('id < ?', id)
                          .maximum(:id)

    if previous_comment_id.nil?
      cursor.destroy!
    else
      cursor.update!(
        last_read_comment_id: previous_comment_id,
        read_at: Time.current
      )
    end
  end

  def mark_as_read(user)
    assigned_tutor = project.tutor_for(task.task_definition)

    CommentReadCursor.transaction do
      advance_read_cursor(user) unless read_by?(user)
      remove_unneeded_staff_cursors(assigned_tutor) if user == assigned_tutor
    end
  end

  def mark_as_unread(user)
    remove_comment_read_entry(user)
  end

  def new_for?(user)
    requires_attention_for?(user) && !read_by?(user)
  end

  def read_by?(user)
    return true if self.user == user || !requires_attention_for?(user)

    cursor = CommentReadCursor.find_by(task_id: task_id, user_id: user.id)
    cursor.present? && cursor.last_read_comment_id >= id
  end

  def time_read_by(user)
    return nil unless requires_attention_for?(user)

    cursor = CommentReadCursor.find_by(task_id: task_id, user_id: user.id)
    cursor&.read_at if cursor&.last_read_comment_id.to_i >= id
  end

  def requires_attention_for?(user)
    return true if attention_audience.nil?
    return attention_student? if task.student_participant?(user)

    attention_staff?
  end

  def rewind_comment_read_cursors
    previous_comment_id = TaskComment
                          .where(task_id: task_id)
                          .where('id < ?', id)
                          .maximum(:id)

    cursors = CommentReadCursor.where(last_read_comment_id: id)
    if previous_comment_id.nil?
      cursors.delete_all
    else
      # A single comment can be the cursor for every teaching staff member.
      # Keep destruction bounded to one SQL update.
      # rubocop:disable Rails/SkipsModelValidations
      cursors.update_all(
        last_read_comment_id: previous_comment_id,
        updated_at: Time.current
      )
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  private

  def remove_unneeded_staff_cursors(assigned_tutor)
    retained_user_ids = task.student_participant_ids << assigned_tutor.id
    CommentReadCursor.where(task_id: task_id).where.not(user_id: retained_user_ids).delete_all
  end

  def set_default_attention_audience
    return if attention_audience.present? || user.nil? || task.nil?
    return if task.group_submission.present? && task.student_participant?(user)

    self.attention_audience = user == task.project.student ? :staff : :student
  end
end
