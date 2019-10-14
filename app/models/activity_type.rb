class ActivityType < ActiveRecord::Base
  # Relationships
  has_many :unit_activity_sets

  before_destroy :can_destroy?

  validates :name,         presence: true
  validates :abbreviation, presence: true

  def can_destroy?
    return true if unit_activity_sets.count == 0
    errors.add :base, "Cannot delete ActivityType with unit_activity_sets"
    false
  end
end
