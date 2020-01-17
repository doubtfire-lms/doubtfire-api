require 'test_helper'

class GroupSetModelTest < ActiveSupport::TestCase

  def test_default_create
    group_set = FactoryGirl.create(:group_set)
    assert group_set.valid?
  end
  
  def test_group_set_exists_in_unit
    unit = FactoryGirl.create(:unit, with_students: false)
  	group_set = FactoryGirl.create(:group_set, unit: unit)
  	assert_includes(unit.group_sets,group_set)
  end
 
end 
