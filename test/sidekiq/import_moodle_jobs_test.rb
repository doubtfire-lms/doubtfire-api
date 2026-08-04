# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ImportMoodleJobsTest < ActiveSupport::TestCase
  test 'student preview reports Moodle data without syncing enrolments' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    integration = unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    moodle = Minitest::Mock.new
    moodle.expect(
      :students,
      [{
        'username' => 'preview.student',
        'idnumber' => '123456',
        'firstname' => 'Preview',
        'lastname' => 'Student',
        'email' => 'preview.student@example.com',
        'roles' => [{ 'shortname' => 'student' }]
      }]
    )
    stored = nil
    job = ImportMoodleStudentsJob.new

    Unit.stub(:find, unit) do
      MoodleApi.stub(:new, moodle) do
        job.stub(:at, nil) do
          job.stub(:total, nil) do
            job.stub(:store, ->(**data) { stored = data }) do
              unit.stub(:sync_enrolment_with, ->(*) { flunk 'Preview must not sync enrolments' }) do
                assert_no_difference -> { unit.projects.count } do
                  job.perform(unit.id, true)
                end
              end
            end
          end
        end
      end
    end

    result = JSON.parse(stored[:result])
    assert_equal 1, result['success'].length
    assert_equal 'preview.student', result['success'].first.dig('row', 'username')
    assert_equal '123456', result['success'].first.dig('row', 'student_id')
    moodle.verify
  end

  test 'student preview reports configured Moodle group mappings without changing students' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    campus = FactoryBot.create(:campus)
    integration = unit.create_moodle_integration!(
      course_id: 42,
      api_key: 'secret-token',
      group_mapping_enabled: true
    )
    integration.moodle_group_mappings.create!(
      moodle_group_id: 31,
      moodle_group_name: 'City students',
      target_type: 'campus',
      campus: campus
    )
    moodle = Minitest::Mock.new
    moodle.expect(
      :students,
      [{
        'id' => 12,
        'username' => 'group.student',
        'idnumber' => '654321',
        'firstname' => 'Group',
        'lastname' => 'Student',
        'email' => 'group.student@example.com',
        'groups' => [{ 'id' => 31, 'name' => 'City students' }],
        'roles' => [{ 'shortname' => 'student' }]
      }]
    )
    stored = nil
    job = ImportMoodleStudentsJob.new

    MoodleApi.stub(:new, moodle) do
      job.stub(:at, nil) do
        job.stub(:total, nil) do
          job.stub(:store, ->(**data) { stored = data }) do
            assert_no_difference -> { unit.projects.count } do
              job.perform(unit.id, true)
            end
          end
        end
      end
    end

    result = JSON.parse(stored[:result])
    assert_equal campus.name, result['success'].first.dig('row', 'mapped_campus')
    assert_equal 'City students', result['success'].first.dig('row', 'moodle_groups')
    moodle.verify
  end

  test 'student group mapping creates a missing group using a unit tutorial' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    project = FactoryBot.create(:project, unit: unit)
    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: project.campus)
    group_set = FactoryBot.create(:group_set, unit: unit)
    TutorialEnrolment.create!(project: project, tutorial: tutorial)
    integration = unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    mapping = integration.moodle_group_mappings.create!(
      moodle_group_id: 31,
      moodle_group_name: 'Moodle Group 1',
      target_type: 'group',
      group_set: group_set,
      create_if_missing: true
    )

    job = ImportMoodleStudentsJob.new
    assert_difference -> { group_set.groups.count }, 1 do
      assert job.send(:apply_mappings, project, [mapping])
    end

    group = group_set.groups.find_by!(name: 'Moodle Group 1')
    assert_equal tutorial, group.tutorial
    assert_equal group, project.reload.group_for_groupset(group_set)
    assert_not job.send(:apply_mappings, project.reload, [mapping])
  end

  test 'extension preview reports calculated days without updating the project' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    user = FactoryBot.create(:user, :student, username: 'extension.student')
    project = FactoryBot.create(:project, unit: unit, user: user, spec_con_days: 0)
    integration = unit.create_moodle_integration!(
      course_id: 42,
      api_key: 'secret-token',
      assignment_id: 7,
      assignment_name: 'Portfolio',
      fetch_extensions: true
    )
    due_date = Time.zone.parse('2026-08-01 09:00:00').to_i
    moodle = Minitest::Mock.new
    moodle.expect(
      :assignments,
      { 'courses' => [{ 'id' => 42, 'assignments' => [{ 'id' => 7, 'duedate' => due_date }] }] }
    )
    moodle.expect(
      :students,
      [
        { 'id' => 12, 'username' => user.username },
        { 'id' => 13, 'username' => 'not.enrolled' }
      ]
    )
    moodle.expect(
      :user_flags,
      {
        'assignments' => [{
          'assignmentid' => 7,
          'userflags' => [
            { 'userid' => 12, 'extensionduedate' => due_date + 2.days.to_i },
            { 'userid' => 13, 'extensionduedate' => due_date + 3.days.to_i }
          ]
        }]
      }
    )
    stored = nil
    job = ImportMoodleExtensionsJob.new

    MoodleApi.stub(:new, moodle) do
      job.stub(:at, nil) do
        job.stub(:total, nil) do
          job.stub(:store, ->(**data) { stored = data }) do
            job.perform(unit.id, true)
          end
        end
      end
    end

    result = JSON.parse(stored[:result])
    assert_equal 0, project.reload.spec_con_days
    assert_equal 2, result['success'].first.dig('row', 'spec_con_days')
    assert_equal '2026-08-03', result['success'].first.dig('row', 'extension_date')
    assert_equal user.username, result['success'].first.dig('row', 'username')
    assert_equal 3, result['ignored'].first.dig('row', 'spec_con_days')
    assert_equal '2026-08-04', result['ignored'].first.dig('row', 'extension_date')
    assert_equal 'not.enrolled', result['ignored'].first.dig('row', 'username')
    moodle.verify
  end
end
