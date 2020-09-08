require "test_helper"

class DeakinConfigTest < ActiveSupport::TestCase
  include TestHelpers::TestFileHelper

  def setup
    @@backup = Doubtfire::Application.config.institution_settings

    ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL'] = 'https://test.com/enrolment'
    ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL'] = 'https://test.com/timetable'

    require "#{Rails.root}/config/deakin"
    Doubtfire::Application.config.institution_settings = DeakinInstitutionSettings.new

    FactoryBot.create(:campus, name:'Cloud (online)', abbreviation: 'X') unless Campus.find_by(abbreviation: 'X').present?
  end

  def teardown
    Doubtfire::Application.config.institution_settings = @@backup
  end

  def test_sync_deakin_unit
    campus = FactoryBot.create(:campus, name: 'Test Sync Campus', abbreviation: 'T')

    # Setup enrolments stud
    raw_enrolment_file = File.new(test_file_path("deakin/enrolment_sample.json"))
    stub_request(:get, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL']}.*/).to_return(body: raw_enrolment_file, status: 200)
    raw_timetable_file = File.new(test_file_path("deakin/timetable_sample.json"))
    stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*allocated$/).to_return(body: raw_timetable_file, status: 200)
    raw_timetable_activity_file = File.new(test_file_path("deakin/timetable_activity_sample.json"))
    stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*activities$/).to_return(body: raw_timetable_activity_file, status: 200)

    tp = FactoryBot.create(:teaching_period, period: 'T2', year: 2020)
    unit = FactoryBot.create(:unit, code: 'SIT999', name: 'Test Sync', teaching_period: tp, with_students: false, stream_count: 0, tutorials: 0)

    assert_equal 0, unit.tutorials.count
    assert_equal 0, unit.projects.count

    unit.sync_enrolments()

    assert_equal 3, unit.projects.count # 3 students and others skipped
    assert_equal 2, unit.tutorials.count # cloud + campus
  end
end
