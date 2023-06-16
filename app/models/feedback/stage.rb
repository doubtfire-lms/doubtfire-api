class Stage < ApplicationRecord
  # Associations
  belongs_to :task_definition
  has_many :criteria, dependent: :destroy
  has_one :unit, through: :task_definition

  # Constraints
  validates_associated :unit
  validates_associated :task_definition
  validates :order, :title, presence: true
  validates :order, numericality: {
    greater_than_or_equal_to: 0, only_integer: true,
    message: "order number must be a positive integer"
  }
  validates :order, uniqueness: {
    scope: :task_definition_id,
    message: "order number must be unique for this task definition"
  }
end
