# frozen_string_literal: true

require 'test_helper'

class PortfolioSubmissionLockApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def create_portfolio_project(locked: true)
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 0,
      campus_count: 0,
      lock_project_on_portfolio_submission: locked
    )
    project = FactoryBot.create(:project, unit: unit)
    FileUtils.touch(project.portfolio_path)
    project.update!(portfolio_production_date: Time.zone.now)
    project
  end

  def delete_portfolio(project)
    delete "/api/submission/project/#{project.id}/portfolio"
  end

  def test_deleting_the_whole_portfolio_unlocks_the_project
    project = create_portfolio_project
    add_auth_header_for(user: project.student)

    assert project.portfolio_locked?

    delete_portfolio(project)
    assert_includes [200, 204], last_response.status

    assert_not project.reload.portfolio_locked?
    assert_not File.exist?(project.portfolio_path)
    assert File.exist?("#{project.portfolio_path}.old")
  end

  def test_removing_a_single_portfolio_file_is_blocked_while_locked
    project = create_portfolio_project
    add_auth_header_for(user: project.student)

    delete "/api/submission/project/#{project.id}/portfolio", idx: 1, kind: 'document', name: 'Notes'

    assert_equal 403, last_response.status
    assert project.reload.portfolio_locked?
  end

  def test_removing_a_single_portfolio_file_is_allowed_when_not_locked
    project = create_portfolio_project(locked: false)
    add_auth_header_for(user: project.student)

    delete "/api/submission/project/#{project.id}/portfolio", idx: 1, kind: 'document', name: 'Notes'

    assert_not_equal 403, last_response.status
  end

  def test_convenor_can_configure_the_portfolio_lock_setting
    project = create_portfolio_project(locked: false)
    unit = project.unit
    add_auth_header_for(user: unit.main_convenor_user)

    put_json(
      "/api/units/#{unit.id}",
      unit: { lock_project_on_portfolio_submission: true }
    )

    assert_equal 200, last_response.status, last_response_body

    get "/api/units/#{unit.id}"
    assert_equal 200, last_response.status, last_response_body
    assert last_response_body['lock_project_on_portfolio_submission']
  end
end
