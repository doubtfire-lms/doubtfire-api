class TutorialStream < ActiveRecord::Base
  belongs_to :activity_type
  belongs_to :unit

  has_many :task_definitions, -> { order 'start_date ASC, abbreviation ASC' }, dependent: :destroy

  validates :name,         presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true
  validates_inclusion_of :combine_all_tasks, :in => [true, false]
end
