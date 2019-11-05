class TutorialStream < ActiveRecord::Base
  belongs_to :activity_type
  belongs_to :unit

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  has_many :task_definitions, -> { order 'start_date ASC, abbreviation ASC' }

  # Always add a unique index with uniqueness constraint
  # This is to prevent new records from passing the validations when checked at the same time before being written
  validates :name,         presence: true, uniqueness: { scope: :unit, message: "%{value} already exists in this unit"}
  validates :abbreviation, presence: true, uniqueness: { scope: :unit, message: "%{value} already exists in this unit"}
  validates_inclusion_of :combine_all_tasks, :in => [true, false]

  private
  def can_destroy?
    return true if task_definitions.empty?
    if unit.tutorial_streams.count > 2
      errors.add :base, "cannot be deleted as it has task definitions associated with it, and it is not the last (or second last) tutorial stream"
      false
    elsif unit.tutorial_streams.count.eql? 2
      other_tutorial_stream = (self.eql? unit.tutorial_streams.first) ? unit.tutorial_streams.second : unit.tutorial_streams.first
      task_definitions.each do |task_definition|
        task_definition.tutorial_stream = other_tutorial_stream
        task_definition.save!
      end
      task_definitions.clear
      true
    elsif unit.tutorial_streams.count.eql? 1
      task_definitions.clear
      true
    end
  end
end
