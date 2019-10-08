class Campus < ActiveRecord::Base
  # Relationships
  has_many    :tutorials, dependent: :delete_all
  has_many    :projects,  dependent: :delete_all

  validates :name, presence: true
  validates :mode, presence: true

  after_save :invalidate_cache

  enum mode: { timetable: 0, automatic: 1, manual: 2 }

  def self.find(id)
    Rails.cache.fetch("campuses/#{id}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by(name: name)
    Rails.cache.fetch("campuses/#{name}", expires_in: 12.hours) do
      super
    end
  end

  private
  def invalidate_cache
    Rails.cache.delete("campuses/#{id}")
    Rails.cache.delete("campuses/#{name}")
  end
end
