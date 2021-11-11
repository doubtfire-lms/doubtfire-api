class CommentsReadReceipts < ApplicationRecord
  validates :user, presence: true
  validates :task_comment, presence: true

  belongs_to :task_comment
  belongs_to :user
end
