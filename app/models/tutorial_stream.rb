class TutorialStream < ApplicationRecord
  belongs_to :activity_type, optional: false
  belongs_to :unit, optional: false

  # Callbacks - methods called are private
  after_create :handle_associated_task_defs
  before_destroy :can_destroy?, prepend: true

  has_many :tutorials, dependent: :destroy
  has_many :task_definitions, dependent: :restrict_with_exception, inverse_of: :tutorial_stream

  # Validations - methods called are private

  validates :unit, presence: true
  validates :activity_type, presence: true

  # Always add a unique index with uniqueness constraint
  # This is to prevent new records from passing the validations when checked at the same time before being written
  validates :name,         presence: true, uniqueness: { scope: :unit, message: "%{value} already exists in this unit" }
  validates :abbreviation, presence: true, uniqueness: { scope: :unit, message: "%{value} already exists in this unit" }

  private

  def can_destroy?
    return true if task_definitions.empty?

    if unit.tutorial_streams.count > 2
      errors.add :base, "cannot be deleted as it has task definitions associated with it, and it is not the last (or second last) tutorial stream"
      throw :abort
    elsif unit.tutorial_streams.count.eql? 2
      other_tutorial_stream = (self.eql? unit.tutorial_streams.first) ? unit.tutorial_streams.second : unit.tutorial_streams.first
      task_definitions.find_each { |td| td.update(tutorial_stream_id: other_tutorial_stream.id) }
      task_definitions.clear
      true
    elsif unit.tutorial_streams.count.eql? 1
      # Removes all objects from the collection by removing their associations from the join table
      task_definitions.clear
      true
    end
  end

  def handle_associated_task_defs
    return if unit.task_definitions.empty? or unit.tutorial_streams.count > 1

    if unit.task_definitions.exists? and unit.tutorial_streams.count.eql? 1
      unit.task_definitions.find_each { |td| td.update(tutorial_stream_id: id) }
    end
  end
end
