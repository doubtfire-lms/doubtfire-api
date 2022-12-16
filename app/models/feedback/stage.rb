class Stage < ApplicationRecord
  belongs_to :task_definition
  has_one :unit, through: :task_definition

  validates :title, :order, presence: true

end
