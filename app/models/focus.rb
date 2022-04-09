class Focus < ApplicationRecord
  belongs_to :unit, optional: false
  has_many :project_focuses, dependent: :destroy
  has_many :task_definition_required_focuses, dependent: :destroy
  has_many :task_comments, dependent: :destroy

end
