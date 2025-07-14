class StaffNote < ApplicationRecord
  belongs_to :project
  belongs_to :user

  # belongs_to :reply_to, class_name: 'StaffNote', optional: true, inverse_of: :replies
  # has_many :replies, class_name: 'StaffNote', dependent: :restrict_with_exception, inverse_of: :reply_to
end
