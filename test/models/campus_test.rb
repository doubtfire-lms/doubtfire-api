require "test_helper"

class CampusTest < ActiveSupport::TestCase

  # FactoryGirl.create will create campus from the values defined in the Campus factory
  # We can override the values as well, for specific test cases it is recommended that we do
  # FactoryGirl.create(:campus, name: 'Burwood')
  def test_default_create
    campus = FactoryGirl.create(:campus)
    assert campus.valid?
  end

  def test_specific_create
    campus = FactoryGirl.create(:campus, name: 'Australia', abbreviation: 'Aus')
    assert_equal(campus.name, 'Australia')
    assert_equal campus.abbreviation, 'Aus'
    assert campus.valid?
  end

  def test_duplicate_campus_is_not_allowed
    campus = FactoryGirl.create(:campus, name: 'Australia', abbreviation: 'Aus')
    campus = FactoryGirl.build(:campus, name: 'Australia', abbreviation: 'Aus')
    assert campus.invalid?
  end
end
