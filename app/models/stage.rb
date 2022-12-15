class Stage < ApplicationRecord
  belongs_to :task_definition

  validates :title, :order, presence: true

end
