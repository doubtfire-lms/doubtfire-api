class TaskComment < ActiveRecord::Base
	belongs_to :task       # Foreign key
	belongs_to :user

	validates :task, presence: true
	validates :user, presence: true
	validates :comment, presence: true
end
