class TaskPin < ApplicationRecord
  belongs_to :task, optional: false
  belongs_to :user, optional: false
end
