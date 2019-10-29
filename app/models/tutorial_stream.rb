class TutorialStream < ActiveRecord::Base
  belongs_to :activity_type
  belongs_to :unit

  validates :name,         presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true
  validates_inclusion_of :combine_all_tasks, :in => [true, false]
end
