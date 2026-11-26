require 'test_helper'

class SubmissionHistoryApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_group_member_can_view_submission_history_and_overseer_assessment
    setup_group_submission
    history = FactoryBot.create(:submission_history, task: @tasks.first.reload)
    assessment = FactoryBot.create(
      :overseer_assessment,
      task: @tasks.first,
      submission_history: history,
      submission_timestamp: history.submission_timestamp
    )
    add_auth_header_for(user: @projects.second.student)

    get submission_histories_path(@projects.second)

    assert_equal 200, last_response.status, last_response.body
    assert_equal [history.id], last_response_body.pluck('id')

    get overseer_assessments_path(@projects.second)

    assert_equal 200, last_response.status, last_response.body
    assert_equal [assessment.id], last_response_body.pluck('id')
  end

  private

  def setup_group_submission
    unit = FactoryBot.create(:unit, student_count: 3, task_count: 1)
    @projects = unit.active_projects.first(3)
    @task_definition = unit.task_definitions.first
    group_set = FactoryBot.create(:group_set, unit: unit)
    @task_definition.update!(group_set: group_set)
    @group = FactoryBot.create(:group, group_set: group_set, tutorial: unit.tutorials.first)
    @tasks = @projects.first(2).map do |project|
      @group.add_member(project)
      project.task_for_task_definition(@task_definition)
    end
    @group.create_submission(
      @tasks.first,
      'Group submission',
      @tasks.map { |task| { project: task.project, pct: 50, pts: 3 } }
    )
    @tasks
  end

  def submission_histories_path(project)
    "/api/projects/#{project.id}/task_def_id/#{@task_definition.id}/submission_histories"
  end

  def overseer_assessments_path(project)
    "/api/projects/#{project.id}/task_def_id/#{@task_definition.id}/submissions/timestamps"
  end
end
