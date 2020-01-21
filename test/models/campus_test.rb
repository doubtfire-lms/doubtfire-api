require "test_helper"

class CampusTest < ActiveSupport::TestCase

  # FactoryBot.create will create campus from the values defined in the Campus factory
  # We can override the values as well, for specific test cases it is recommended that we do
  # FactoryBot.create(:campus, name: 'Burwood')
  def test_default_create
    campus = FactoryBot.create(:campus)
    assert campus.valid?
  end

  def test_specific_create
    campus = FactoryBot.create(:campus, name: 'Australia', abbreviation: 'Aus')
    assert_equal(campus.name, 'Australia')
    assert_equal campus.abbreviation, 'Aus'
    assert campus.valid?
  end

  def test_duplicate_campus_is_not_allowed
    campus = FactoryBot.create(:campus, name: 'Australia', abbreviation: 'Aus')
    campus = FactoryBot.build(:campus, name: 'Australia', abbreviation: 'Aus')
    assert campus.invalid?
  end

  def test_find_cached
    id = Campus.first.id
    Rails.cache.clear
    activity_type = Campus.find(id)
    assert Rails.cache.exist?("campuses/#{id}")
  end

  def test_find_by_name_cached
    name = Campus.first.name
    Rails.cache.clear
    activity_type = Campus.find_by(name: name)
    assert Rails.cache.exist?("campuses/name=#{name}")
  end

  def test_find_by_abbreviation_cached
    abbreviation = Campus.first.abbreviation
    Rails.cache.clear
    activity_type = Campus.find_by(abbreviation: abbreviation)
    assert Rails.cache.exist?("campuses/abbreviation=#{abbreviation}")
  end
end
