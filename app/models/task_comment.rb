class TaskComment < ActiveRecord::Base
  belongs_to :task # Foreign key
  belongs_to :user

  belongs_to :recipient, class_name: 'User'

  has_many :comments_read_receipts, class_name: 'CommentsReadReceipts', dependent: :destroy, inverse_of: :task_comment

  validates :task, presence: true
  validates :user, presence: true
  validates :recipient, presence: true
  validates :comment, length: { minimum: 0, maximum: 4095, allow_blank: true }
  has_attached_file :attachment, :styles => {
    :medium => { :geometry => "640x480", :format => 'flv' },
    :thumb => { :geometry => "100x100#", :format => 'jpg', :time => 10 }
  }, :processors => [:transcoder], :path => proc { |attachment| FileHelper.comment_attachment_path(attachment.instance, attachment) }
  do_not_validate_attachment_file_type :attachment

  def new_for?(user)
    CommentsReadReceipts.where(user: user, task_comment_id: self).empty?
  end

  def create_comment_read_receipt_entry(user)
    comment_read_receipt = CommentsReadReceipts.find_or_create_by(user: user, task_comment: self)
    comment_read_receipt.user = user
    comment_read_receipt.task_comment = self
    comment_read_receipt.save!
  end

  def add_attachment(tempfile)
    attachmenttodisplay = {
      :filename => tempfile[:filename],
      :type => tempfile[:type],
      :headers => tempfile[:head],
      :tempfile => tempfile[:tempfile]
    }
    self.attachment = ActionDispatch::Http::UploadedFile.new(attachmenttodisplay)    
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

  def mark_as_unread(user)
    remove_comment_read_entry(user)
  end

  def time_read_by(user)
    read_reciept = CommentsReadReceipts.find_by(user: user, task_comment: self)
    read_reciept.created_at unless read_reciept.nil?
  end
end
