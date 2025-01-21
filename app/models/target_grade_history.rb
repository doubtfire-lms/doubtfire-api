class TargetGradeHistory < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :changed_by, class_name: 'User', foreign_key: 'changed_by_id'

  validates :project_id, :user_id, :previous_grade, :new_grade, :changed_at, presence: true
end
