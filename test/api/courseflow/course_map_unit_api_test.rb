require 'test_helper'

class CourseMapUnitTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::JsonHelper
  include TestHelpers::AuthHelper

  def app
    Rails.application
  end

  def test_get_course_map_units_by_course_map_id
    course_map = FactoryBot.create(:course_map)
    course_map_unit1 = FactoryBot.create(:course_map_unit, courseMapId: course_map.id)
    course_map_unit2 = FactoryBot.create(:course_map_unit, courseMapId: course_map.id)
    course_map_unit3 = FactoryBot.create(:course_map_unit, courseMapId: course_map.id)
    add_auth_header_for user: User.first
    get "/api/coursemapunit/courseMapId/#{course_map.id}"
    assert_equal 3, JSON.parse(last_response.body).size
  ensure
    course_map.destroy
    course_map_unit1.destroy
    course_map_unit2.destroy
    course_map_unit3.destroy
  end

  def test_create_course_map_unit
    course_map = FactoryBot.create(:course_map)
    unit_id = 100
    data_to_post = { courseMapId: course_map.id, unitId: unit_id, yearSlot: 2022, teachingPeriodSlot: 1, unitSlot: 1 }
    add_auth_header_for user: User.first
    post_json "/api/coursemapunit", data_to_post
    assert Courseflow::CourseMapUnit.exists?(courseMapId: course_map.id, unitId: unit_id, yearSlot: 2022, teachingPeriodSlot: 1, unitSlot: 1)
  ensure
    course_map.destroy
  end

  def test_update_course_map_unit
    course_map_unit = FactoryBot.create(:course_map_unit)
    updated_data = { courseMapId: course_map_unit.courseMapId, unitId: course_map_unit.unitId, yearSlot: 2023, teachingPeriodSlot: course_map_unit.teachingPeriodSlot, unitSlot: course_map_unit.unitSlot }
    add_auth_header_for user: User.first
    put_json "/api/coursemapunit/courseMapUnitId/#{course_map_unit.id}", updated_data
    assert_equal 200, last_response.status
  ensure
    course_map_unit.destroy
  end

  def test_delete_course_map_unit_by_id
    course_map_unit = FactoryBot.create(:course_map_unit)
    add_auth_header_for user: User.first
    delete "/api/coursemapunit/courseMapUnitId/#{course_map_unit.id}"
    assert_equal 0, Courseflow::CourseMapUnit.where(id: course_map_unit.id).count
  ensure
    course_map_unit.destroy
  end

  def test_delete_course_map_units_by_course_map_id
    course_map = FactoryBot.create(:course_map)
    coursemapunit1 = FactoryBot.create(:course_map_unit, courseMapId: course_map.id)
    coursemapunit2 = FactoryBot.create(:course_map_unit, courseMapId: course_map.id)
    coursemapunit3 = FactoryBot.create(:course_map_unit, courseMapId: course_map.id)
    add_auth_header_for user: User.first
    delete "/api/coursemapunit/courseMapId/#{course_map.id}"
    assert_equal 0, Courseflow::CourseMapUnit.where(courseMapId: course_map.id).count
  ensure
    course_map.destroy
    coursemapunit1.destroy
    coursemapunit2.destroy
    coursemapunit3.destroy
  end

  def test_delete_course_map_unit_unauthorized
    course_map_unit = FactoryBot.create(:course_map_unit)
    delete "/api/coursemapunit/courseMapUnitId/#{course_map_unit.id}"
    assert_equal 419, last_response.status
  ensure
    course_map_unit.destroy
  end

end
