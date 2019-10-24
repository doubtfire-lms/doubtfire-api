require "test_helper"

class ActivityTypeTest < ActiveSupport::TestCase
  def test_default_create
    activity_type = FactoryGirl.create(:activity_type)
    assert activity_type.valid?
  end

  def test_specific_create
    activity_type = FactoryGirl.create(:activity_type, name: 'Seminar', abbreviation: 'sem')
    assert_equal(activity_type.name, 'Seminar')
    assert_equal activity_type.abbreviation, 'sem'
    assert activity_type.valid?
  end

  def test_duplicate_activity_type_is_not_allowed
    activity_type = FactoryGirl.create(:activity_type, name: 'Seminar', abbreviation: 'sem')
    activity_type = FactoryGirl.build(:activity_type, name: 'Seminar', abbreviation: 'sem')
    assert activity_type.invalid?
  end

  def test_duplicate_activity_type_name_is_not_allowed
    activity_type = FactoryGirl.create(:activity_type, name: 'Seminar')
    activity_type = FactoryGirl.build(:activity_type, name: 'Seminar')
    assert activity_type.invalid?
  end

  def test_duplicate_activity_type_abbreviation_is_not_allowed
    activity_type = FactoryGirl.create(:activity_type, abbreviation: 'sem')
    activity_type = FactoryGirl.build(:activity_type, abbreviation: 'sem')
    assert activity_type.invalid?
  end
end
