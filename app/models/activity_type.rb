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

  def self.find_by(*args)
    key = args.map { |arg|
      if arg.instance_of? Hash
        arg.map{|k,v| "#{k}=#{v}"}.join('/')
      else
        arg
      end
    }.join('/')

    Rails.cache.fetch("activity_types/#{key}", expires_in: 12.hours) do
      super
    end
  end

  def self.find_by_abbr_or_name(data)
    ActivityType.find_by(abbreviation: data) || ActivityType.find_by(name: data)
  end

  private
  def invalidate_cache
    Rails.cache.delete("activity_types/#{id}")
    Rails.cache.delete("activity_types/name=#{name}")
    Rails.cache.delete("activity_types/abbreviation=#{abbreviation}")
  end
end
