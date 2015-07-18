#
# Tracks each group's submissions.
#
class GroupSubmission < ActiveRecord::Base
  belongs_to :group
  has_many :tasks, dependent: :nullify
  belongs_to :submitted_by_project, class_name: "Project", foreign_key: 'submitted_by_project_id'
  
end
