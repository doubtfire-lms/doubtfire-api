# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class SyncMoodleIntegrationsJobTest < ActiveSupport::TestCase
  test 'queues both imports for a current active unit' do
    travel_to Time.zone.local(2026, 8, 4, 3, 0, 0) do
      unit = create_unit(start_date: 1.week.ago, end_date: 1.week.from_now)
      create_integration(unit: unit, auto_sync_students: true, auto_sync_extensions: true)

      assert_queued_imports students: [[unit.id, false]], extensions: [[unit.id, false]]
    end
  end

  test 'only queues extensions during the fourteen day grace period' do
    travel_to Time.zone.local(2026, 8, 4, 3, 0, 0) do
      unit = create_unit(start_date: 15.weeks.ago, end_date: 1.week.ago)
      create_integration(unit: unit, auto_sync_students: true, auto_sync_extensions: true)

      assert_queued_imports students: [], extensions: [[unit.id, false]]
    end
  end

  test 'does not queue imports outside their date windows' do
    travel_to Time.zone.local(2026, 8, 4, 3, 0, 0) do
      future_unit = create_unit(start_date: 1.week.from_now, end_date: 15.weeks.from_now)
      ended_unit = create_unit(start_date: 20.weeks.ago, end_date: 3.weeks.ago)
      create_integration(unit: future_unit, auto_sync_students: true, auto_sync_extensions: true)
      create_integration(unit: ended_unit, auto_sync_students: true, auto_sync_extensions: true)

      assert_queued_imports students: [], extensions: []
    end
  end

  test 'does not queue imports for a disabled or inactive unit' do
    travel_to Time.zone.local(2026, 8, 4, 3, 0, 0) do
      disabled_unit = create_unit(start_date: 1.week.ago, end_date: 1.week.from_now, moodle_enabled: false)
      inactive_unit = create_unit(start_date: 1.week.ago, end_date: 1.week.from_now, active: false)
      create_integration(unit: disabled_unit, auto_sync_students: true, auto_sync_extensions: true)
      create_integration(unit: inactive_unit, auto_sync_students: true, auto_sync_extensions: true)

      assert_queued_imports students: [], extensions: []
    end
  end

  test 'requires extension imports and an assignment before scheduling extensions' do
    travel_to Time.zone.local(2026, 8, 4, 3, 0, 0) do
      unit = create_unit(start_date: 1.week.ago, end_date: 1.week.from_now)
      create_integration(
        unit: unit,
        auto_sync_extensions: true,
        fetch_extensions: false,
        assignment_id: nil
      )

      assert_queued_imports students: [], extensions: []
    end
  end

  private

  def create_unit(start_date:, end_date:, active: true, moodle_enabled: true)
    FactoryBot.create(
      :unit,
      with_students: false,
      start_date: start_date,
      end_date: end_date,
      active: active,
      moodle_enabled: moodle_enabled
    )
  end

  def create_integration(unit:, auto_sync_students: false, auto_sync_extensions: false,
                         fetch_extensions: true, assignment_id: 7)
    unit.create_moodle_integration!(
      course_id: unit.id,
      api_key: 'secret-token',
      assignment_id: assignment_id,
      fetch_extensions: fetch_extensions,
      auto_sync_students: auto_sync_students,
      auto_sync_extensions: auto_sync_extensions
    )
  end

  def assert_queued_imports(students:, extensions:)
    queued_students = []
    queued_extensions = []

    student_enqueue = ->(unit_id, preview_only) { queued_students << [unit_id, preview_only] }
    extension_enqueue = ->(unit_id, preview_only) { queued_extensions << [unit_id, preview_only] }

    ImportMoodleStudentsJob.stub(:perform_async, student_enqueue) do
      ImportMoodleExtensionsJob.stub(:perform_async, extension_enqueue) do
        SyncMoodleIntegrationsJob.new.perform
      end
    end

    assert_equal students, queued_students
    assert_equal extensions, queued_extensions
  end
end
