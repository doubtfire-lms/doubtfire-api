require "test_helper"

class ActivityTypeModelTest < ActiveSupport::TestCase
  def test_default_create
    activity_type = FactoryBot.create(:activity_type)
    assert activity_type.valid?
  end

  def test_specific_create
    activity_type = FactoryBot.create(:activity_type, name: 'Seminar', abbreviation: 'sem')
    assert_equal(activity_type.name, 'Seminar')
    assert_equal activity_type.abbreviation, 'sem'
    assert activity_type.valid?
  end

  def test_duplicate_activity_type_is_not_allowed
    activity_type = FactoryBot.create(:activity_type, name: 'Seminar', abbreviation: 'sem')
    activity_type = FactoryBot.build(:activity_type, name: 'Seminar', abbreviation: 'sem')
    assert activity_type.invalid?
  end

  def test_duplicate_activity_type_name_is_not_allowed
    activity_type = FactoryBot.create(:activity_type, name: 'Seminar')
    activity_type = FactoryBot.build(:activity_type, name: 'Seminar')
    assert activity_type.invalid?
  end

  def test_duplicate_activity_type_abbreviation_is_not_allowed
    activity_type = FactoryBot.create(:activity_type, abbreviation: 'sem')
    activity_type = FactoryBot.build(:activity_type, abbreviation: 'sem')
    assert activity_type.invalid?
  end

  def test_find_cached
    id = ActivityType.first.id
    Rails.cache.clear
    activity_type = ActivityType.find(id)
    assert Rails.cache.exist?("activity_types/#{id}")
  end

  def test_find_by_name_cached
    name = ActivityType.first.name
    Rails.cache.clear
    activity_type = ActivityType.find_by(name: name)
    assert Rails.cache.exist?("activity_types/name=#{name}")
  end

  def test_find_by_abbreviation_cached
    abbreviation = ActivityType.first.abbreviation
    Rails.cache.clear
    activity_type = ActivityType.find_by(abbreviation: abbreviation)
    assert Rails.cache.exist?("activity_types/abbreviation=#{abbreviation}")
  end

  def test_find_by_name_exclamation_cached
    name = ActivityType.first.name
    Rails.cache.clear
    assert_not Rails.cache.exist?("activity_types/name=#{name}")
    activity_type = ActivityType.find_by!(name: name)
    assert Rails.cache.exist?("activity_types/name=#{name}")
  end
end
