# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class MoodleIntegrationApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  test 'convenor can save and read Moodle settings without exposing the API key' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    add_auth_header_for(user: unit.main_convenor_user)

    put "/api/units/#{unit.id}/moodle", {
      course_id: 42,
      api_key: 'secret-token',
      assignment_id: 7,
      assignment_name: 'Portfolio',
      fetch_extensions: true,
      auto_sync_students: true,
      auto_sync_extensions: true,
      group_mapping_enabled: true,
      group_mappings: [{
        moodle_group_id: 31,
        moodle_group_name: 'Hawthorn',
        target_type: 'campus',
        campus_id: FactoryBot.create(:campus).id,
        create_if_missing: false
      }]
    }

    assert_equal 200, last_response.status, last_response.inspect
    integration = unit.reload.moodle_integration
    assert_equal 42, integration.course_id
    assert_equal 'secret-token', integration.api_key
    assert_equal 'Portfolio', integration.assignment_name
    assert integration.fetch_extensions
    assert integration.auto_sync_students
    assert integration.auto_sync_extensions
    assert integration.group_mapping_enabled
    assert_not integration.validated
    assert_equal 'Hawthorn', integration.moodle_group_mappings.first.moodle_group_name
    assert_equal integration.id, last_response_body['id']
    assert_equal true, last_response_body['api_key_configured']
    assert_not last_response.body.include?('secret-token')

    get "/api/units/#{unit.id}/moodle"
    assert_equal 42, last_response_body['course_id']
    assert_equal 7, last_response_body['assignment_id']
    assert_equal 'Portfolio', last_response_body['assignment_name']
    assert_equal true, last_response_body['fetch_extensions']
    assert_equal true, last_response_body['auto_sync_students']
    assert_equal true, last_response_body['auto_sync_extensions']
    assert_equal true, last_response_body['group_mapping_enabled']
    assert_equal false, last_response_body['validated']
    assert_equal 31, last_response_body['group_mappings'].first['moodle_group_id']
    assert_nil last_response_body['api_key']
  end

  test 'student cannot manage Moodle settings' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    add_auth_header_for(user: FactoryBot.create(:user, :student))

    get "/api/units/#{unit.id}/moodle"

    assert_equal 403, last_response.status
  end

  test 'Moodle settings are unavailable when the integration is disabled' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: false)
    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/units/#{unit.id}/moodle"

    assert_equal 404, last_response.status
    assert_equal 'Moodle integration is not enabled for this unit', last_response_body['error']
  end

  test 'connection endpoint returns the permission report' do
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      moodle_enabled: true
    )
    unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    add_auth_header_for(user: unit.main_convenor_user)
    job = {
      'jid' => 'moodle-job-id',
      'status' => 'queued',
      'at' => 0,
      'total' => 6
    }

    TestMoodleConnectionJob.stub(:perform_async, 'moodle-job-id') do
      Sidekiq::Status.stub(:get_all, job) do
        Sidekiq::Status.stub(:store_for_id, true) do
          post "/api/units/#{unit.id}/moodle/test"
        end
      end
    end

    assert_equal 201, last_response.status, last_response.inspect
    assert_equal 'moodle-job-id', last_response_body['id']
    assert_equal 6, last_response_body['total_count'].to_i
  end

  test 'Moodle imports enqueue preview and import jobs' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    unit.create_moodle_integration!(
      course_id: 42,
      api_key: 'secret-token',
      assignment_id: 7,
      assignment_name: 'Portfolio',
      fetch_extensions: true,
      validated: true,
      validated_at: Time.current
    )
    add_auth_header_for(user: unit.main_convenor_user)
    queued = []
    job = { 'jid' => 'moodle-import-job', 'status' => 'queued', 'at' => 0, 'total' => 0 }

    students_enqueue = lambda do |unit_id, preview_only|
      queued << [:students, unit_id, preview_only]
      'moodle-import-job'
    end
    extensions_enqueue = lambda do |unit_id, preview_only|
      queued << [:extensions, unit_id, preview_only]
      'moodle-import-job'
    end

    ImportMoodleStudentsJob.stub(:perform_async, students_enqueue) do
      ImportMoodleExtensionsJob.stub(:perform_async, extensions_enqueue) do
        Sidekiq::Status.stub(:get_all, job) do
          Sidekiq::Status.stub(:store_for_id, true) do
            post "/api/units/#{unit.id}/moodle/import_students", preview_only: true
            assert_equal 201, last_response.status, last_response.inspect

            post "/api/units/#{unit.id}/moodle/import_extensions", preview_only: false
            assert_equal 201, last_response.status, last_response.inspect
          end
        end
      end
    end

    assert_equal [[:students, unit.id, true], [:extensions, unit.id, false]], queued
  end

  test 'Moodle integration validation enqueues a validation job' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    add_auth_header_for(user: unit.main_convenor_user)
    job = { 'jid' => 'moodle-validation-job', 'status' => 'queued', 'at' => 0, 'total' => 1 }

    ValidateMoodleIntegrationJob.stub(:perform_async, 'moodle-validation-job') do
      Sidekiq::Status.stub(:get_all, job) do
        Sidekiq::Status.stub(:store_for_id, true) do
          post "/api/units/#{unit.id}/moodle/validate"
        end
      end
    end

    assert_equal 201, last_response.status, last_response.inspect
    assert_equal 'moodle-validation-job', last_response_body['id']
  end

  test 'student import requires a validated Moodle integration' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    add_auth_header_for(user: unit.main_convenor_user)

    post "/api/units/#{unit.id}/moodle/import_students", preview_only: true

    assert_equal 422, last_response.status
    assert_equal 'Validate the Moodle integration before importing students', last_response_body['error']
  end

  test 'extension import requires a validated Moodle integration' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    unit.create_moodle_integration!(
      course_id: 42,
      api_key: 'secret-token',
      fetch_extensions: true,
      assignment_id: 7,
      assignment_name: 'Portfolio'
    )
    add_auth_header_for(user: unit.main_convenor_user)

    post "/api/units/#{unit.id}/moodle/import_extensions", preview_only: true

    assert_equal 422, last_response.status
    assert_equal 'Validate the Moodle integration before importing extensions', last_response_body['error']
  end

  test 'student cannot validate the Moodle integration' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    add_auth_header_for(user: FactoryBot.create(:user, :student))

    post "/api/units/#{unit.id}/moodle/validate"

    assert_equal 403, last_response.status
  end

  test 'group mapping pre-fill delegates to institution settings without persisting records' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    add_auth_header_for(user: unit.main_convenor_user)
    settings = Minitest::Mock.new
    groups = [{ id: 31, name: 'Tutorial A', idnumber: 'T-A' }]
    settings.expect(
      :prefill_moodle_group_mappings,
      [{ moodle_group_id: 31, moodle_group_name: 'Tutorial A', target_type: 'ignore' }],
      [unit, groups]
    )
    mapping_count = unit.moodle_integration.moodle_group_mappings.count
    tutorial_count = unit.tutorials.count

    Doubtfire::Application.config.stub(:institution_settings, settings) do
      post "/api/units/#{unit.id}/moodle/prefill_group_mappings", groups: groups
    end

    assert_equal 201, last_response.status, last_response.inspect
    assert_equal 'ignore', last_response_body['group_mappings'].first['target_type']
    assert_equal mapping_count, unit.moodle_integration.moodle_group_mappings.count
    assert_equal tutorial_count, unit.tutorials.count
    settings.verify
  end

  test 'student cannot pre-fill Moodle group mappings' do
    unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    unit.create_moodle_integration!(course_id: 42, api_key: 'secret-token')
    add_auth_header_for(user: FactoryBot.create(:user, :student))

    post "/api/units/#{unit.id}/moodle/prefill_group_mappings", groups: [{ id: 31, name: 'Tutorial A' }]

    assert_equal 403, last_response.status
  end
end
