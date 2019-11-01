class TutorialStream < ActiveRecord::Base
  belongs_to :activity_type
  belongs_to :unit

  has_many :task_definitions, -> { order 'start_date ASC, abbreviation ASC' }, dependent: :destroy

  # Always add a unique index with uniqueness constraint
  # This is to prevent new records from passing the validations when checked at the same time before being written
  validates :name,         presence: true, uniqueness: { scope: :unit, message: "%{value} already exists in this unit"}
  validates :abbreviation, presence: true, uniqueness: { scope: :unit, message: "%{value} already exists in this unit"}
  validates_inclusion_of :combine_all_tasks, :in => [true, false]
end
