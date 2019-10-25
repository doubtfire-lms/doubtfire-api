class ActivityType < ActiveRecord::Base

  validates :name,         presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true

  after_destroy :invalidate_cache
  after_save :invalidate_cache

  def self.find(id)
    Rails.cache.fetch("activity_types/#{id}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by(name)
    Rails.cache.fetch("activity_types/#{name}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by(abbreviation)
    Rails.cache.fetch("activity_types/#{abbreviation}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by_abbr_or_name(data)
    ActivityType.find_by(abbreviation: data) || ActivityType.find_by(name: data)
  end

  private
  def invalidate_cache
    Rails.cache.delete("activity_types/#{id}")
    Rails.cache.delete("activity_types/#{name}")
    Rails.cache.delete("activity_types/#{abbreviation}")
  end
end
