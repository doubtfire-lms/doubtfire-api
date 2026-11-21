require "test_helper"

class ProjectChannelTest < ActionCable::Channel::TestCase
  include ActionCable::TestHelper

  setup do
    @unit = FactoryBot.create(:unit, student_count: 2, task_count: 1, stream_count: 0)
    @project = @unit.projects.first
    @task_definition = @unit.task_definitions.first
  end

  def test_student_streams_own_project
    stub_connection current_user: @project.student

    subscribe project_id: @project.id

    assert_has_stream ProjectChannel.stream_name(@project.id)
  end

  def test_rejects_other_student
    stub_connection current_user: @unit.projects.where.not(id: @project.id).first.student

    subscribe project_id: @project.id

    assert subscription.rejected?
  end

  def test_task_events_include_task_definition
    task = @project.task_for_task_definition(@task_definition)

    assert_broadcast_on(
      ProjectChannel.stream_name(@project.id),
      { event: 'comment_created', task_definition_id: @task_definition.id }
    ) do
      task.add_text_comment(@unit.main_convenor_user, 'Hello')
    end
  end
end
