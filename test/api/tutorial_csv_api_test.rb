require 'test_helper'

class TutorialCsvApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_convenor_can_download_tutorial_streams_and_tutorials_csv
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    stream = unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)
    unit.add_tutorial('Monday', '10:00', 'ATC101', tutor, nil, 20, 'T1', stream)

    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/units/#{unit.id}/tutorial_streams/csv"
    assert_equal 200, last_response.status, last_response.body
    assert_equal 'attachment; filename=COS10001-TutorialStreams.csv', last_response.headers['content-disposition']
    assert_equal unit.tutorial_streams_csv, last_response.body

    get "/api/units/#{unit.id}/tutorials/csv"
    assert_equal 200, last_response.status, last_response.body
    assert_equal 'attachment; filename=COS10001-Tutorials.csv', last_response.headers['content-disposition']
    assert_equal unit.tutorials_csv, last_response.body
  end

  def test_student_cannot_download_tutorial_streams_or_tutorials_csv
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    student = FactoryBot.create(:user, :student)

    add_auth_header_for(user: student)

    %w[tutorial_streams tutorials].each do |csv_type|
      get "/api/units/#{unit.id}/#{csv_type}/csv"
      assert_equal 403, last_response.status, csv_type
    end
  end

  def test_convenor_can_upload_tutorial_streams_csv
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    activity_type = FactoryBot.create(:activity_type)

    csv_file = Tempfile.new(['tutorial-streams-upload', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[abbreviation name activity_type]
      csv << ['wrk-1', 'Workshop', activity_type.abbreviation]
    end)
    csv_file.rewind

    add_auth_header_for(user: unit.main_convenor_user)
    post "/api/units/#{unit.id}/tutorial_streams/csv", file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv')

    assert_equal 201, last_response.status, last_response.body
    assert_equal 1, last_response_body['success'].size
    assert_equal 'Created stream wrk-1.', last_response_body['success'].first['message']
    assert unit.tutorial_streams.find_by(abbreviation: 'wrk-1').present?
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_convenor_can_upload_tutorials_csv
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    unit.add_tutorial_stream('Lab', 'lab-1', FactoryBot.create(:activity_type))
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    csv_file = Tempfile.new(['tutorials-upload', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << Tutorial.csv_columns
      csv << ['T9', 'lab-1', 'Tuesday', '11:00', 'ATC102', nil, nil, tutor.username, nil]
    end)
    csv_file.rewind

    add_auth_header_for(user: unit.main_convenor_user)
    post "/api/units/#{unit.id}/tutorials/csv", file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv')

    assert_equal 201, last_response.status, last_response.body
    assert_equal 'Created tutorial T9.', last_response_body['success'].first['message']
    assert_equal tutor, unit.tutorials.find_by(abbreviation: 'T9').tutor
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_only_convenors_and_admins_can_upload_tutorial_csvs
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.tutorials.destroy_all
    activity_type = FactoryBot.create(:activity_type)
    unit.add_tutorial_stream('Lab', 'lab-1', activity_type)
    student = FactoryBot.create(:user, :student)
    tutor = FactoryBot.create(:user, :tutor)
    unit.enrol_student(student, nil)
    unit.employ_staff(tutor, Role.tutor)

    streams_file = Tempfile.new(['tutorial-streams-permissions', '.csv'])
    streams_file.write("abbreviation,name,activity_type\nwrk-1,Workshop,#{activity_type.abbreviation}\n")
    streams_file.rewind

    tutorials_file = Tempfile.new(['tutorials-permissions', '.csv'])
    tutorials_file.write("#{Tutorial.csv_columns.join(',')}\nT9,lab-1,Tuesday,11:00,ATC102,,,,\n")
    tutorials_file.rewind

    [tutor, student].each do |user|
      add_auth_header_for(user: user)

      post "/api/units/#{unit.id}/tutorial_streams/csv", file: Rack::Test::UploadedFile.new(streams_file.path, 'text/csv')
      assert_equal 403, last_response.status, user.role.name

      post "/api/units/#{unit.id}/tutorials/csv", file: Rack::Test::UploadedFile.new(tutorials_file.path, 'text/csv')
      assert_equal 403, last_response.status, user.role.name
    end

    assert_nil unit.tutorial_streams.find_by(abbreviation: 'wrk-1')
    assert_equal 0, unit.tutorials.count
  ensure
    streams_file&.close
    streams_file&.unlink
    tutorials_file&.close
    tutorials_file&.unlink
  end

  def test_tutorial_csv_uploads_reject_non_csv_files
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    add_auth_header_for(user: unit.main_convenor_user)

    %w[tutorial_streams tutorials].each do |csv_type|
      post "/api/units/#{unit.id}/#{csv_type}/csv", file: upload_file('test_files/COS10001-Tasks.zip', 'application/zip')
      assert_equal 403, last_response.status, csv_type
      assert_equal 'File given is not a csv file - detected application/zip; charset=binary', last_response_body['error']
    end
  end

  def test_tutorial_csv_uploads_require_a_file
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    add_auth_header_for(user: unit.main_convenor_user)

    %w[tutorial_streams tutorials].each do |csv_type|
      post "/api/units/#{unit.id}/#{csv_type}/csv"
      assert_equal 400, last_response.status, csv_type
    end
  end
end
