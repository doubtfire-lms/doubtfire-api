# frozen_string_literal: true

require 'test_helper'

class PortfolioSubmissionLockApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActiveSupport::Testing::TimeHelpers
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def create_portfolio_project(deadline: '2026-08-17T10:00')
    campus = FactoryBot.create(:campus, timezone: 'UTC')
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 0,
      campus_count: 0,
      lock_project_on_portfolio_submission: true,
      portfolio_deadline: deadline,
      portfolio_deadline_per_campus: true
    )
    project = FactoryBot.create(:project, unit: unit, campus: campus)
    FileUtils.touch(project.portfolio_path)
    project.update!(portfolio_production_date: Time.zone.now)
    project
  end

  def delete_portfolio(project, confirm_late: nil)
    path = "/api/submission/project/#{project.id}/portfolio"
    if confirm_late.nil?
      delete path
    else
      delete path, { confirm_late: confirm_late }.to_json, 'CONTENT_TYPE' => 'application/json'
    end
  end

  def test_student_must_confirm_deletion_after_effective_deadline
    project = create_portfolio_project

    travel_to(Time.zone.parse('2026-08-17 10:00:01 UTC')) do
      add_auth_header_for(user: project.student)
      delete_portfolio(project)

      assert_equal 409, last_response.status
      assert last_response_body['portfolio_late_confirmation_required']
      assert_equal '2026-08-17T10:00:00Z', last_response_body['effective_portfolio_deadline']
      assert_equal 'UTC', last_response_body['effective_portfolio_deadline_timezone']
      assert project.reload.portfolio_locked?

      delete_portfolio(project, confirm_late: true)
      assert_includes [200, 204], last_response.status
    end

    assert_not project.reload.portfolio_locked?
    assert_not File.exist?(project.portfolio_path)
    assert File.exist?("#{project.portfolio_path}.old")
  end

  def test_exact_deadline_does_not_require_late_confirmation
    project = create_portfolio_project

    travel_to(Time.zone.parse('2026-08-17 10:00:00 UTC')) do
      add_auth_header_for(user: project.student)
      delete_portfolio(project)
      assert_includes [200, 204], last_response.status
    end
  end

  def test_compiling_portfolio_cannot_be_deleted
    project = create_portfolio_project(deadline: nil)
    FileUtils.rm_f(project.portfolio_path)
    project.update!(compile_portfolio: true, portfolio_production_date: nil)
    add_auth_header_for(user: project.student)

    delete_portfolio(project)

    assert_equal 409, last_response.status
    assert_match(/still compiling/, last_response_body['error'])
    assert project.reload.portfolio_locked?
  end

  def test_tutor_cannot_delete_a_portfolio
    project = create_portfolio_project(deadline: nil)
    tutor = FactoryBot.create(:user, :tutor)
    project.unit.employ_staff(tutor, Role.tutor)
    add_auth_header_for(user: tutor)

    delete_portfolio(project)

    assert_equal 403, last_response.status
    assert project.reload.portfolio_locked?
  end

  def test_convenor_can_delete_a_portfolio
    project = create_portfolio_project(deadline: nil)
    convenor = FactoryBot.create(:user, :convenor)
    project.unit.employ_staff(convenor, Role.convenor)
    add_auth_header_for(user: convenor)

    delete_portfolio(project)

    assert_includes [200, 204], last_response.status
    assert_not project.reload.portfolio_locked?
  end

  def test_convenor_can_configure_and_read_portfolio_submission_settings
    project = create_portfolio_project(deadline: nil)
    unit = project.unit
    timezone_campus = FactoryBot.create(:campus, timezone: 'Australia/Perth')
    add_auth_header_for(user: unit.main_convenor_user)

    put_json(
      "/api/units/#{unit.id}",
      unit: {
        portfolio_deadline: '2026-09-12T17:45',
        portfolio_deadline_per_campus: false,
        portfolio_deadline_campus_id: timezone_campus.id,
        lock_project_on_portfolio_submission: true
      }
    )

    assert_equal 200, last_response.status, last_response_body
    get "/api/units/#{unit.id}"
    assert_equal 200, last_response.status, last_response_body
    assert_equal '2026-09-12T17:45', last_response_body['portfolio_deadline']
    assert_not last_response_body['portfolio_deadline_per_campus']
    assert_equal timezone_campus.id, last_response_body['portfolio_deadline_campus_id']
    assert last_response_body['lock_project_on_portfolio_submission']
  end
end
