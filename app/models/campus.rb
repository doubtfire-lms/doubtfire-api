class Campus < ActiveRecord::Base
  # Relationships
  has_many    :tutorials
  has_many    :projects

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  # Always add a unique index with uniqueness constraint
  # This is to prevent new records from passing the validations when checked at the same time before being written
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

  def self.find_by(*args)
    key = args.map { |arg|
      if arg.instance_of? Hash
        arg.map{|k,v| "#{k}=#{v}"}.join('/')
      else
        arg
      end
    }.join('/')

    Rails.cache.fetch("campuses/#{key}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by_abbr_or_name(data)
    Campus.find_by(abbreviation: data) || Campus.find_by(name: data)
  end

  private
  def invalidate_cache
    Rails.cache.delete("campuses/#{id}")
    Rails.cache.delete("campuses/name=#{name}")
    Rails.cache.delete("campuses/abbreviation=#{abbreviation}")
  end

  def can_destroy?
    return true if projects.count == 0 and tutorials.count == 0
    errors.add :base, "Cannot delete campus with projects and tutorials"
    false
  end
end
