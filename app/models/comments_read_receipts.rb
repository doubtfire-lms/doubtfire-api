class CommentsReadReceipts < ActiveRecord::Base
  validates :user, presence: true
  validates :task_comment, presence: true
  validates :created_at, presence: true

  belongs_to :task_comment
  belongs_to :user
end
