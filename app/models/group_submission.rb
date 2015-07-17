#
# Tracks each group's submissions.
#
class GroupSubmission < ActiveRecord::Base
  belongs_to :groups
  has_many :tasks, dependent: :nullify

end
