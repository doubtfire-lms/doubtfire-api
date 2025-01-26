class ActivityType < ApplicationRecord
  has_many :tutorial_streams, dependent: :restrict_with_exception

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  # Always add a unique index with uniqueness constraint
  # This is to prevent new records from passing the validations when checked at the same time before being written
  validates :name,         presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true

  after_destroy :invalidate_cache
  after_save :invalidate_cache

  def self.find(id)
    Rails.cache.fetch("activity_types/#{id}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by(*args)
    key = args.map { |arg|
      if arg.instance_of? Hash
        arg.map { |k, v| "#{k}=#{v}" }.join('/')
      else
        arg
      end
    }.join('/')

    Rails.cache.fetch("activity_types/#{key}", expires_in: 12.hours) do
      super
    end
  end

  private

  def invalidate_cache
    Rails.cache.delete("activity_types/#{id}")
    Rails.cache.delete("activity_types/name=#{name}")
    Rails.cache.delete("activity_types/abbreviation=#{abbreviation}")
  end

  def can_destroy?
    return true if tutorial_streams.count == 0

    errors.add :base, "Cannot delete activity type with associated tutorial_streams"
    throw :abort
  end
end
