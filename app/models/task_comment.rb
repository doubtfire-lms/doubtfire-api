class TaskComment < ActiveRecord::Base
  belongs_to :task # Foreign key
  belongs_to :user

  belongs_to :recipient, class_name: 'User'

  has_many :comments_read_receipts, class_name: 'CommentsReadReceipts', dependent: :destroy, inverse_of: :task_comment

  validates :task, presence: true
  validates :user, presence: true
  validates :recipient, presence: true
  validates :comment, length: { minimum: 1, maximum: 4095, allow_blank: false }

  def new_for?(user)
    CommentsReadReceipts.where(user: user, task_comment_id: self).empty?
  end

  def create_comment_read_receipt_entry(user)
    comment_read_receipt = CommentsReadReceipts.find_or_create_by(user: user, task_comment: self)
    comment_read_receipt.user = user
    comment_read_receipt.task_comment = self
    comment_read_receipt.save!
  end

  def remove_comment_read_entry(user)
    CommentsReadReceipts.delete_all(user: user, task_comment: self)
  end

  def mark_as_read(user, unit)
    if user == task.project.main_tutor
      unit.staff.each do |staff_member|
        create_comment_read_receipt_entry(staff_member.user)
      end
    else
      create_comment_read_receipt_entry(user)
    end
  end

  def mark_as_unread(user, unit)
    if user == task.project.main_tutor
      unit.staff.each do |staff_member|
        remove_comment_read_entry(staff_member.user)
      end
    else
      remove_comment_read_entry(user)
    end
  end

  def time_read_by(user)
    CommentsReadReceipts.find_by(user: user, task_comment: self).created_at if CommentsReadReceipts.find_by(user: user, task_comment: self)
  end
end
