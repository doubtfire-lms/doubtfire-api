# frozen_string_literal: true

require 'test_helper'

class CustomInstitutionSettingTest < ActiveSupport::TestCase
  setup do
    @settings = Doubtfire::Application.config.institution_settings
    skip 'Custom Moodle group mapping settings are not installed' unless @settings.respond_to?(:moodle_tutorial_details)

    @burwood = Campus.find_by(abbreviation: 'BU') || FactoryBot.create(:campus, name: 'Burwood', abbreviation: 'BU')
    @geelong = Campus.find_by(abbreviation: 'GE') || FactoryBot.create(:campus, name: 'Geelong', abbreviation: 'GE')
    @online = Campus.find_by(abbreviation: 'OL') || FactoryBot.create(:campus, name: 'Online', abbreviation: 'OL')
    campus_details = {
      'BU' => { suffix: 'bu', names: %w[BU Burwood] },
      'GE' => { suffix: 'ge', names: %w[GE Geelong] },
      'OL' => { suffix: 'ol', names: %w[OL Online] }
    }
    @settings.define_singleton_method(:moodle_campus_details) { campus_details }
    @unit = FactoryBot.create(:unit, with_students: false)

    workshop = ActivityType.where(name: 'Workshop').first_or_create!(abbreviation: 'WRK')
    seminar = ActivityType.where(name: 'Seminar').first_or_create!(abbreviation: 'SEM')
    @workshop_stream = FactoryBot.create(:tutorial_stream, unit: @unit, activity_type: workshop)
    @seminar_stream = FactoryBot.create(:tutorial_stream, unit: @unit, activity_type: seminar)
  end

  test 'pre-fills local and regional timetable activities' do
    suggestions = @settings.prefill_moodle_group_mappings(
      @unit,
      [
        { id: 1, name: 'Allocate+ COS10001 Workshop 07_OnCampus BU_Building.B2.123 Tue 10:00 (24)' },
        { id: 2, name: 'Allocate+ COS10001 Workshop 08 GE_Room_2.15 Fri 14:30 (30)' }
      ]
    )

    local = suggestions.first[:tutorial_draft]
    assert_equal ['workshop-07-bu', @burwood.id, @workshop_stream.id, 'Building.B2.123', 'Tuesday', '10:00', 24],
                 local.values_at(
                   :abbreviation,
                   :campus_id,
                   :tutorial_stream_id,
                   :meeting_location,
                   :meeting_day,
                   :meeting_time,
                   :capacity
                 )

    regional = suggestions.second[:tutorial_draft]
    assert_equal 'workshop-08-ge', regional[:abbreviation]
    assert_equal @geelong.id, regional[:campus_id]
    assert_equal 'Room_2.15', regional[:meeting_location]
  end

  test 'makes repeated activity abbreviations unique and ignores unrelated groups' do
    suggestions = @settings.prefill_moodle_group_mappings(
      @unit,
      [
        { id: 1, name: 'Allocate+ COS10001 Seminar 03_OnCampus-P1 OL_Site.Room_5 Mon 09:00' },
        { id: 2, name: 'Allocate+ COS10001 Seminar 03_OnCampus-P2 OL_Site.Room_5 Thu 15:00' },
        { id: 3, name: 'Allocate+ COS10001 Workshop 09 GE_Room_4 Wed 11:00 (20)' },
        { id: 4, name: 'Allocate+ COS10001 Workshop 09 GE_Room_4 Fri 13:00 (20)' },
        { id: 5, name: 'Course participants' }
      ]
    )

    abbreviations = suggestions.filter_map { |suggestion| suggestion.dig(:tutorial_draft, :abbreviation) }
    assert_equal %w[seminar-03-p1-ol seminar-03-p2-ol workshop-09-wed-1100-ge workshop-09-fri-1300-ge],
                 abbreviations
    assert_equal @online.id, suggestions.first.dig(:tutorial_draft, :campus_id)
    assert_equal @seminar_stream.id, suggestions.first.dig(:tutorial_draft, :tutorial_stream_id)
    assert_equal 'Site.Room_5', suggestions.first.dig(:tutorial_draft, :meeting_location)
    assert_equal 'ignore', suggestions.last[:target_type]
  end

  test 'selects an existing tutorial instead of returning a draft' do
    existing = FactoryBot.create(
      :tutorial,
      unit: @unit,
      tutorial_stream: @workshop_stream,
      campus: @burwood,
      abbreviation: 'workshop-07-bu'
    )
    suggestion = @settings.prefill_moodle_group_mappings(
      @unit,
      [{ id: 1, name: 'Allocate+ COS10001 Workshop 07_OnCampus BU_Building.B2.123 Tue 10:00 (24)' }]
    ).first

    assert_equal existing.id, suggestion[:tutorial_id]
    assert_equal @workshop_stream.id, suggestion[:tutorial_stream_id]
    assert_nil suggestion[:tutorial_draft]
  end
end
