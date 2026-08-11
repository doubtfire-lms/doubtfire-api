# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class MoodleApiTest < ActiveSupport::TestCase
  setup do
    settings = Struct.new(:course_id, :api_key, :assignment_id).new(42, 'token', nil)
    @integration = MoodleApi.new(settings)
  end

  test 'connection test reports each required permission and course assignments' do
    assignments = {
      'courses' => [{
        'id' => 42,
        'fullname' => 'Programming 1',
        'shortname' => 'COS10001',
        'assignments' => [{ 'id' => 7, 'name' => 'Portfolio', 'duedate' => 100 }]
      }]
    }
    students = [{
      'id' => 12,
      'username' => 'student',
      'roles' => [{ 'shortname' => 'student' }]
    }]
    groups = [{ 'id' => 31, 'name' => 'Tutorial A', 'idnumber' => 'T-A' }]
    course_details = {
      'courses' => [{
        'id' => 42,
        'fullname' => 'Programming 1',
        'shortname' => 'COS10001',
        'startdate' => 1_775_347_200,
        'enddate' => 1_786_838_400
      }]
    }

    @integration.stub(:course_details, course_details) do
      @integration.stub(:assignments, assignments) do
        @integration.stub(:students, students) do
          @integration.stub(:user_flags, {}) do
            @integration.stub(:course_groups, groups) do
              result = @integration.test_connection

              assert_equal 'Programming 1', result[:course]['fullname']
              assert_equal 1_775_347_200, result[:course]['startdate']
              assert_equal 1_786_838_400, result[:course]['enddate']
              assert_equal 'Portfolio', result[:assignments].first['name']
              assert_equal 'Tutorial A', result[:groups].first['name']
              assert_equal %w[mod_assign_get_assignments core_course_get_courses_by_field core_enrol_get_enrolled_users mod_assign_get_user_flags core_group_get_course_groups], result[:permissions].pluck(:function)
              assert(result[:permissions].all? { |permission| permission[:success] })
            end
          end
        end
      end
    end
  end

  test 'connection test reports an individual failed permission' do
    @integration.stub(:course_details, { 'courses' => [] }) do
      @integration.stub(:assignments, { 'courses' => [] }) do
        @integration.stub(:students, []) do
          @integration.stub(:course_groups, []) do
            result = @integration.test_connection

            flags = result[:permissions].find { |permission| permission[:function] == 'mod_assign_get_user_flags' }
            assert_not flags[:success]
          end
        end
      end
    end
  end
end
