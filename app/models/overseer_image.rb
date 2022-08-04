class OverseerImage < ApplicationRecord
  # Callbacks - methods called are private
  before_destroy :can_destroy?

  has_many :units
  has_many :task_definitions

  # Always add a unique index with uniqueness constraint
  # This is to prevent new records from passing the validations when checked at the same time before being written
  validates :name,  presence: true, uniqueness: true
  validates :tag,   presence: true, uniqueness: true

  private

  def can_destroy?
    return true if units.count == 0 && task_definitions.count == 0

    errors.add :base, "Cannot delete overseer image with associated units and/or task definitions"
    throw :abort
  end
end
