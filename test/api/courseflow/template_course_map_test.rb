require 'test_helper'

class TemplateCourseMapTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::JsonHelper
  include TestHelpers::AuthHelper

  def app
    Rails.application
  end

  def setup
    # Create teaching period if needed
    @teaching_period = TeachingPeriod.first || FactoryBot.create(:teaching_period)

    # Create users needed for testing
    @convenor_user1 = User.find_by(username: 'acain') || FactoryBot.create(:user, username: 'acain', nickname: 'Macite')
    @convenor_user2 = User.find_by(username: 'aconvenor') || FactoryBot.create(:user, username: 'aconvenor', nickname: 'The Giant')
    @tutor_user = User.find_by(username: 'cliff') || FactoryBot.create(:user, username: 'cliff', nickname: 'Cliff')

    # Create units required for course map
    create_sit_units

    # Create a template course map (userId=nil)
    @template_course_map = Courseflow::CourseMap.create(courseId: 1, userId: nil)

    # Create the course map units based on your seeds.rb structure
    create_course_map_units

    # Create a test student user that has no course map
    @student_without_course_map = FactoryBot.create(:user, :student)
  end

  def teardown
    # Clean up course map units
    Courseflow::CourseMapUnit.where(courseMapId: @template_course_map.id).destroy_all
    # Clean up course map
    @template_course_map.destroy if @template_course_map

  end

  def create_sit_units
    # Define the SIT units
    @sit_units = {
      sit111: { code: "SIT111", name: "Computer Systems" },
      sit192: { code: "SIT192", name: "Discrete Mathematics" },
      sit112: { code: "SIT112", name: "Introduction to Data Science and Artificial Intelligence" },
      sit102: { code: "SIT102", name: "Introduction to Programming" },
      sit232: { code: "SIT232", name: "Object-Oriented Development" },
      sit103: { code: "SIT103", name: "Database Fundamentals" },
      sit292: { code: "SIT292", name: "Linear Algebra for Data Analysis" },
      sit202: { code: "SIT202", name: "Computer Networks and Communication" },
      sit221: { code: "SIT221", name: "Data Structures and Algorithms" },
      sit215: { code: "SIT215", name: "Computational Intelligence" },
      sit223: { code: "SIT223", name: "Professional Practice in Information Technology" },
      sit320: { code: "SIT320", name: "Advanced Algorithms" },
      sit344: { code: "SIT344", name: "Professional Practice" },
      sit378: { code: "SIT378", name: "Team Project (B)" },
      sit315: { code: "SIT315", name: "Concurrent and Distributed Programming" }
    }

    # Store the created units for later reference
    @created_units = {}

    # Create each unit if it doesn't exist
    @sit_units.each do |key, unit_data|
      # Skip if the unit already exists
      existing_unit = Unit.find_by(code: unit_data[:code])
      if existing_unit
        @created_units[key] = existing_unit
        next
      end

      # Create the unit
      unit = Unit.create!(
        code: unit_data[:code],
        name: unit_data[:name],
        description: "#{unit_data[:name]} unit description",
        teaching_period: @teaching_period
      )

      # Employ staff
      unit.employ_staff(@convenor_user1, Role.convenor)
      unit.employ_staff(@convenor_user2, Role.convenor)
      unit.employ_staff(@tutor_user, Role.tutor)

      # Store for later use
      @created_units[key] = unit
    end
  end

    def create_course_map_units
    units_data = [
      { unit: :sit111, year: 2024, teaching_period: 1, slot: 1 },
      { unit: :sit192, year: 2024, teaching_period: 1, slot: 2 },
      { unit: :sit112, year: 2024, teaching_period: 1, slot: 3 },
      { unit: :sit102, year: 2024, teaching_period: 1, slot: 4 },
      
      { unit: :sit232, year: 2024, teaching_period: 2, slot: 1 },
      { unit: :sit103, year: 2024, teaching_period: 2, slot: 2 },
      { unit: :sit292, year: 2024, teaching_period: 2, slot: 3 },
      { unit: :sit202, year: 2024, teaching_period: 2, slot: 4 },
      
      { unit: :sit221, year: 2025, teaching_period: 1, slot: 1 },
      { unit: :sit215, year: 2025, teaching_period: 1, slot: 2 },
      
      { unit: :sit223, year: 2025, teaching_period: 2, slot: 1 },
      { unit: :sit320, year: 2025, teaching_period: 2, slot: 2 },
      { unit: :sit315, year: 2025, teaching_period: 2, slot: 3 },
      
      { unit: :sit344, year: 2026, teaching_period: 1, slot: 1 },
      
      { unit: :sit378, year: 2026, teaching_period: 2, slot: 1 }
    ]
  
    units_data.each do |unit_data|
      Courseflow::CourseMapUnit.create(
        courseMapId: @template_course_map.id,
        unitId: @created_units[unit_data[:unit]].id,
        yearSlot: unit_data[:year],
        teachingPeriodSlot: unit_data[:teaching_period],
        unitSlot: unit_data[:slot]
      )
    end
  end

  #
  # Tests
  #

  def test_get_template_course_map_when_user_has_no_course_map
    add_auth_header_for user: @student_without_course_map

    get "/api/coursemap/userId/#{@student_without_course_map.id}"

    assert_equal 200, last_response.status

    response_data = JSON.parse(last_response.body)

    assert_equal @template_course_map.id, response_data['id']
    assert_equal @template_course_map.courseId, response_data['courseId']
    assert_nil response_data['userId']  # Template has nil userId
  end

  def test_user_course_map_prioritized_over_template
    student_with_map = FactoryBot.create(:user, :student)
    personal_course_map = Courseflow::CourseMap.create(courseId: 1, userId: student_with_map.id)

    Courseflow::CourseMapUnit.create(
      courseMapId: personal_course_map.id,
      unitId: @created_units[:sit111].id,
      yearSlot: 2030, 
      teachingPeriodSlot: 3, 
      unitSlot: 5  
    )

    add_auth_header_for user: student_with_map

    get "/api/coursemap/userId/#{student_with_map.id}"

    assert_equal 200, last_response.status

    response_data = JSON.parse(last_response.body)

    # Verify that the personal course map was returned, not the template
    assert_equal personal_course_map.id, response_data['id']
    assert_equal personal_course_map.courseId, response_data['courseId']
    assert_equal student_with_map.id, response_data['userId']
  ensure
    Courseflow::CourseMapUnit.where(courseMapId: personal_course_map.id).destroy_all if personal_course_map
    personal_course_map.destroy if personal_course_map
  end

  def test_course_map_units_for_template
    add_auth_header_for user: @student_without_course_map

    # Request the course map units for the template
    get "/api/coursemapunit/courseMapId/#{@template_course_map.id}"

    assert_equal 200, last_response.status

    response_data = JSON.parse(last_response.body)

    # Verify that we got all course map units
    assert_equal 15, response_data.length

    # Verify first unit is SIT111 in the first year and period
    first_unit = response_data.find { |unit| unit['unitSlot'] == 1 && unit['yearSlot'] == 2024 && unit['teachingPeriodSlot'] == 1 }
    assert_not_nil first_unit
    assert_equal @created_units[:sit111].id, first_unit['unitId']
  end

  def test_template_course_map_structure
    course_map_units = Courseflow::CourseMapUnit.where(courseMapId: @template_course_map.id)

    # Verify we have units in each expected year and period
    assert_equal 4, course_map_units.where(yearSlot: 2024, teachingPeriodSlot: 1).count
    assert_equal 4, course_map_units.where(yearSlot: 2024, teachingPeriodSlot: 2).count
    assert_equal 2, course_map_units.where(yearSlot: 2025, teachingPeriodSlot: 1).count
    assert_equal 3, course_map_units.where(yearSlot: 2025, teachingPeriodSlot: 2).count
    assert_equal 1, course_map_units.where(yearSlot: 2026, teachingPeriodSlot: 1).count
    assert_equal 1, course_map_units.where(yearSlot: 2026, teachingPeriodSlot: 2).count
  end
end
