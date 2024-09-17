require "test_helper"

class DeakinConfigTest < ActiveSupport::TestCase
  include TestHelpers::TestFileHelper
  include DbHelpers

  setup do
    @@backup = Doubtfire::Application.config.institution_settings

    ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL'] = 'https://test.com/enrolment'
    ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL'] = 'https://test.com/timetable'

    require "#{Rails.root}/config/deakin"
    Doubtfire::Application.config.institution_settings = DeakinInstitutionSettings.new

    # Rename and adjust abbreviation of all other campuses... so we can make sure they have the right details
    Campus.update_all "name = #{db_concat("'Test-'", "name")}, abbreviation = #{db_concat("'-'", "abbreviation")}"

    FactoryBot.create(:campus, name: 'Test Sync Campus', abbreviation: 'T')
    FactoryBot.create(:campus, name: 'Online', abbreviation: 'C')
  end

  def teardown
    Doubtfire::Application.config.institution_settings = @@backup
  end

  def test_sync_deakin_unit
    WebMock.reset_executed_requests!

    # Setup enrolments stub
    raw_enrolment_file = File.new(test_file_path("deakin/enrolment_sample.json"))
    enrolment_stub = stub_request(:get, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL']}.*/).to_return(body: raw_enrolment_file, status: 200)

    raw_timetable_file = File.new(test_file_path("deakin/timetable_sample.json"))
    timetable_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*allocated$/).to_return(body: raw_timetable_file, status: 200)

    raw_timetable_activity_file = File.new(test_file_path("deakin/timetable_activity_sample.json"))
    timetable_activity_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*activities$/).to_return(body: raw_timetable_activity_file, status: 200)

    tp = FactoryBot.create(:teaching_period, period: 'T2', year: 2020)
    unit = FactoryBot.create(:unit, code: 'SIT999', name: 'Test Sync', teaching_period: tp, with_students: false, stream_count: 0, tutorials: 0)

    assert_equal 0, unit.tutorials.count
    assert_equal 0, unit.projects.count

    result = unit.sync_enrolments()

    assert_equal 3, unit.projects.count, result # 3 students and others skipped
    assert_equal 1, unit.tutorials.count, result # campus

    assert_requested enrolment_stub
    assert_requested timetable_stub
    assert_requested timetable_activity_stub

    unit.destroy
  end

  def test_sync_deakin_unit_without_timetable
    WebMock.reset_executed_requests!

    # Setup enrolments stubs
    raw_enrolment_file = File.new(test_file_path("deakin/enrolment_sample.json"))
    enrolment_stub = stub_request(:get, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL']}.*/).to_return(body: raw_enrolment_file, status: 200)

    raw_timetable_file = File.new(test_file_path("deakin/timetable_sample.json"))
    timetable_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*allocated$/).to_return(body: raw_timetable_file, status: 200)

    raw_timetable_cls_activity_file = File.new(test_file_path("deakin/timetable_activity_sample.json"))
    timetable_activity_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*activities$/).to_return(body: raw_timetable_cls_activity_file, status: 200)

    tp = FactoryBot.create(:teaching_period, period: 'T2', year: 2020)
    unit = FactoryBot.create(:unit, code: 'SIT999', name: 'Test Sync', teaching_period: tp, with_students: false, stream_count: 0, tutorials: 0)

    unit.enable_sync_timetable = false
    unit.save

    unit.sync_enrolments

    assert_equal 0, unit.tutorials.count # none created

    assert_requested enrolment_stub
    assert_not_requested timetable_stub
    assert_not_requested timetable_activity_stub

    unit.destroy
  end

  def test_sync_deakin_retry_requests
    WebMock.reset_executed_requests!

    # Setup enrolments stubs
    raw_enrolment_file = File.new(test_file_path("deakin/enrolment_sample.json"))
    enrolment_stub = stub_request(:get, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL']}.*/)
                     .to_return([
                                  { body: "Too many requests", status: 429 },
                                  { body: "Internal server error", status: 500 },
                                  { body: raw_enrolment_file, status: 200 }
                                ])

    raw_timetable_file = File.new(test_file_path("deakin/timetable_sample.json"))
    timetable_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*allocated$/).
      to_return([
                  { body: "Too many requests", status: 429 },
                  { body: "Internal server error", status: 500 },
                  { body: raw_timetable_file, status: 200 }
                ])

    raw_timetable_cls_activity_file = File.new(test_file_path("deakin/timetable_activity_sample.json"))
    timetable_activity_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*activities$/).
      to_return([
                  { body: "Too many requests", status: 429 },
                  { body: "Internal server error", status: 500 },
                  { body: raw_timetable_cls_activity_file, status: 200 }
                ])

    tp = FactoryBot.create(:teaching_period, period: 'T2', year: 2020)
    unit = FactoryBot.create(:unit, code: 'SIT999', name: 'Test Sync', teaching_period: tp, with_students: false, stream_count: 0, tutorials: 0)

    unit.sync_enrolments

    assert_requested enrolment_stub, times: 3
    assert_requested timetable_stub, times: 3
    assert_requested timetable_activity_stub, times: 3

    unit.destroy
  end

  def test_sync_deakin_multi_unit
    WebMock.reset_executed_requests!

    # Setup enrolments stubs
    raw_enrolment_file_1 = File.new(test_file_path("deakin/enrol_multi_1.json"))
    raw_enrolment_file_2 = File.new(test_file_path("deakin/enrol_multi_2.json"))
    raw_enrolment_file_3 = File.new(test_file_path("deakin/enrol_multi_1.json"))
    raw_enrolment_file_4 = File.new(test_file_path("deakin/enrol_multi_2.json"))

    enrolment_stub = stub_request(:get, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL']}.*/).
      to_return([
                  { body: raw_enrolment_file_1, status: 200 },
                  { body: raw_enrolment_file_2, status: 200 },
                  { body: raw_enrolment_file_3, status: 200 },
                  { body: raw_enrolment_file_4, status: 200 }
                ])

    tp = FactoryBot.create(:teaching_period, period: 'T2', year: 2024)
    unit = FactoryBot.create(:unit, code: 'SIT724/SIT746', name: 'Test Sync', teaching_period: tp, with_students: false, stream_count: 0, tutorials: 0)

    unit.enable_sync_timetable = false
    unit.save

    result = unit.sync_enrolments

    assert_equal 2, unit.tutorials.count # none created

    assert_requested enrolment_stub, times: 2

    assert_equal 2, unit.active_projects.count

    unit.reload
    result = unit.sync_enrolments

    assert_equal 2, unit.active_projects.count

    unit.destroy
  end

  def test_sync_deakin_unit_disabled
    WebMock.reset_executed_requests!

    # Setup enrolments stubs
    raw_enrolment_file = File.new(test_file_path("deakin/enrolment_sample.json"))
    enrolment_stub = stub_request(:get, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_BASE_URL']}.*/).to_return(body: raw_enrolment_file, status: 200)

    raw_timetable_file = File.new(test_file_path("deakin/timetable_sample.json"))
    timetable_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*allocated$/).to_return(body: raw_timetable_file, status: 200)

    raw_timetable_activity_file = File.new(test_file_path("deakin/timetable_activity_sample.json"))
    timetable_activity_stub = stub_request(:post, /#{ENV['DF_INSTITUTION_SETTINGS_SYNC_STAR_URL']}.*activities$/).to_return(body: raw_timetable_activity_file, status: 200)

    tp = FactoryBot.create(:teaching_period, period: 'T2', year: 2020)
    unit = FactoryBot.create(:unit, code: 'SIT999', name: 'Test Sync', teaching_period: tp, with_students: false, stream_count: 0, tutorials: 0)

    unit.enable_sync_enrolments = false
    unit.save
    # unit.update enable_sync_timetable: false

    unit.sync_enrolments()

    assert_equal 0, unit.tutorials.count # none created

    assert_not_requested enrolment_stub
    assert_not_requested timetable_stub
    assert_not_requested timetable_activity_stub

    unit.destroy
  end
end
