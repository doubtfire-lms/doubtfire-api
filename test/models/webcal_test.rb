require 'test_helper'

class WebcalTest < ActiveSupport::TestCase
  setup do
    # Create student
    @student = FactoryBot.create(:user, :student)
    @campus = FactoryBot.create(:campus)

    # Create ongoing units
    @current_unit_1 = FactoryBot.create(:unit, task_count: 10)
    @current_unit_1.enrol_student(@student, @campus)
    @current_project_1 = Project.find_by(user: @student, unit: @current_unit_1)
    @current_project_1.update(target_grade: 3)

    @current_unit_2 = FactoryBot.create(:unit, task_count: 10)
    @current_unit_2.enrol_student(@student, @campus)
    @current_project_2 = Project.find_by(user: @student, unit: @current_unit_2)
    @current_project_2.update(target_grade: 3)

    # Create old unit
    @old_unit = FactoryBot.create(:unit, task_count: 2)
    @old_unit.enrol_student(@student, @campus)
    @old_unit.active = false
    @old_unit.start_date -= 1.year
    @old_unit.end_date -= 1.year
    @old_unit.save!
    @old_project = Project.find_by(user: @student, unit: @old_unit)
    @old_project.update(target_grade: 3)

    # Create webcal
    @webcal = @student.create_webcal(guid: SecureRandom.uuid)
  end

  teardown do
    @webcal.destroy
    @student.destroy
    @old_unit.destroy
    @current_unit_1.destroy
    @current_unit_2.destroy
    @campus.destroy
  end

  test 'Includes only task definitions of current units' do
    expected_ids = @current_unit_1.task_definitions.map(&:id) + @current_unit_2.task_definitions.map(&:id)
    actual_ids = @webcal.task_definitions.map(&:id)
    assert_equal expected_ids.sort, actual_ids.sort
  end

  test 'Includes only task definitions that are targeted' do
    # Update target grade to a distinction.
    g = 2
    @current_project_1.update(target_grade: g)
    @current_project_2.update(target_grade: g)

    # Ensure only tasks that are <= distinction are included.
    expected_ids = @current_unit_1.task_definitions.where("target_grade <= #{g}").map(&:id) + @current_unit_2.task_definitions.where("target_grade <= #{g}").map(&:id)
    actual_ids = @webcal.task_definitions.map(&:id)

    assert_equal expected_ids.sort, actual_ids.sort
  end

  test 'Includes only task definitions of units that aren\'t excluded' do
    # Exclude unit 2
    @webcal.webcal_unit_exclusions.create(unit: @current_unit_2)

    # Ensure tasks of unit 2 are excluded
    expected_ids = @current_unit_1.task_definitions.map(&:id)
    actual_ids = @webcal.task_definitions.map(&:id)

    assert_equal expected_ids.sort, actual_ids.sort

    @webcal.webcal_unit_exclusions.find_by(unit: @current_unit_2).destroy
  end

  test 'Includes events with target dates of all task definitions' do
    cal = @webcal.to_ical
    expected_task_defs = @current_unit_1.task_definitions + @current_unit_2.task_definitions

    assert_equal cal.events.length, expected_task_defs.length

    expected_task_defs.each do |td|
      td_event = cal.events.detect { |e| e.summary == @webcal.event_name_for_task_definition(td, 'end') }
      assert_not_nil td_event
      assert_equal td_event.dtstart.to_date, td.target_date.to_date
      assert_equal td_event.dtend.to_date, td.target_date.to_date
    end
  end

  test 'Includes events for start & end dates if include_start_dates' do
    @webcal.update(include_start_dates: true)

    cal = @webcal.to_ical
    expected_task_defs = @current_unit_1.task_definitions + @current_unit_2.task_definitions

    assert_equal cal.events.length, expected_task_defs.length * 2

    expected_task_defs.each do |td|
      td_start_event = cal.events.detect { |e| e.summary == @webcal.event_name_for_task_definition(td, 'start') }
      assert_not_nil td_start_event
      assert_equal td_start_event.dtstart.to_date, td.start_date.to_date
      assert_equal td_start_event.dtend.to_date, td.start_date.to_date

      td_end_event = cal.events.detect { |e| e.summary == @webcal.event_name_for_task_definition(td, 'end') }
      assert_not_nil td_end_event
      assert_equal td_end_event.dtstart.to_date, td.target_date.to_date
      assert_equal td_end_event.dtend.to_date, td.target_date.to_date
    end

    @webcal.update(include_start_dates: false)
  end

  test 'Includes events with extended date if available' do

    # Apply for an extension on one task
    td = @current_unit_1.task_definitions.first
    task = @current_project_1.task_for_task_definition(td)
    comment = task.apply_for_extension(@student, 'extension', 1)

    # Detect corresponding Ical event
    cal = @webcal.to_ical
    td_event = cal.events.detect { |e| e.summary == @webcal.event_name_for_task_definition(td, 'end') }

    # Ensure date is the extended date, instead of the target date
    assert_equal td_event.dtstart.to_date, td.target_date.to_date + 1.week
    assert_equal td_event.dtend.to_date, td.target_date.to_date + 1.week

    # Revert extension
    comment.destroy
    task.update(extensions: 0)
  end
end
