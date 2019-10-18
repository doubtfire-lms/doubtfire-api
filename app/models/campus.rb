class Campus < ActiveRecord::Base
  # Relationships
  has_many    :tutorials
  has_many    :projects
  has_many    :campus_activity_sets, dependent: :destroy

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  validates :name,         presence: true, uniqueness: true
  validates :mode,         presence: true
  validates :abbreviation, presence: true, uniqueness: true

  validates_inclusion_of :active, :in => [true, false]

  after_destroy :invalidate_cache
  after_save :invalidate_cache

  enum mode: { timetable: 0, automatic: 1, manual: 2 }

  def self.find(id)
    Rails.cache.fetch("campuses/#{id}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by(name)
    Rails.cache.fetch("campuses/#{name}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by_abbr_or_name(data)
    Campus.find_by(abbreviation: data) || Campus.find_by(name: data)
  end

  def add_activity_set(unit_activity_set)
    campus_activity_set = CampusActivitySet.new
    campus_activity_set.unit_activity_set = unit_activity_set
    campus_activity_set.campus = self
    campus_activity_set.save!

    # add after save to ensure valid activity set
    self.campus_activity_sets << campus_activity_set

    campus_activity_set
  end

  def update_activity_set(id, unit_activity_set)
    campus_activity_set = campus_activity_sets.find(id)

    if unit_activity_set.present?
      campus_activity_set.unit_activity_set = unit_activity_set
    end

    campus_activity_set.save!
    campus_activity_set
  end

  private
  def invalidate_cache
    Rails.cache.delete("campuses/#{id}")
    Rails.cache.delete("campuses/#{name}")
  end

  def can_destroy?
    return true if projects.count == 0 and tutorials.count == 0
    errors.add :base, "Cannot delete campus with projects and tutorials"
    false
  end
end
