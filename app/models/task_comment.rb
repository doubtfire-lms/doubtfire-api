class TaskComment < ActiveRecord::Base
  belongs_to :task # Foreign key
  belongs_to :user

  validates :task, presence: true
  validates :user, presence: true
  validates :recipient, presence: true
  validates :is_new, presence: true
  validates :comment, length: { minimum: 1, maximum: 4095, allow_blank: false }

  def new_for?(user)
    if !:is_new then return false
    if (user.role_id != Role.student.id || user.role_id != Role.tutor.id) then return true
    return user == :recipient
  end

  def recipient
    return :task.project.student if :user == :task.project.main_tutor
    return :task.project.main_tutor
  end
end
