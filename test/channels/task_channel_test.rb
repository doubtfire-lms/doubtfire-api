require "test_helper"

class TaskChannelTest < ActionCable::Channel::TestCase
  include ActionCable::TestHelper

  setup do
    @unit = FactoryBot.create(:unit, student_count: 2, task_count: 1, stream_count: 0)
    @project = @unit.projects.first
    @task_definition = @unit.task_definitions.first
  end

  def stream_name
    TaskChannel.stream_name(@project.id, @task_definition.id)
  end

  def test_student_streams_own_task_before_it_exists
    @project.tasks.where(task_definition: @task_definition).destroy_all
    stub_connection current_user: @project.student

    subscribe project_id: @project.id, task_definition_id: @task_definition.id

    assert subscription.confirmed?
    assert_has_stream stream_name
  end

  def test_convenor_streams_student_task
    stub_connection current_user: @unit.main_convenor_user

    subscribe project_id: @project.id, task_definition_id: @task_definition.id

    assert_has_stream stream_name
  end

  def test_rejects_other_student
    stub_connection current_user: @unit.projects.where.not(id: @project.id).first.student

    subscribe project_id: @project.id, task_definition_id: @task_definition.id

    assert subscription.rejected?
  end

  def test_rejects_task_definition_from_another_unit
    other_task_definition = FactoryBot.create(:unit, student_count: 0, task_count: 1, stream_count: 0).task_definitions.first
    stub_connection current_user: @project.student

    subscribe project_id: @project.id, task_definition_id: other_task_definition.id

    assert subscription.rejected?
  end

  def test_comment_broadcasts_to_task_stream
    task = @project.task_for_task_definition(@task_definition)

    assert_broadcast_on(stream_name, { event: 'comment_created' }) do
      task.add_text_comment(@unit.main_convenor_user, 'Hello')
    end
  end

  def test_broadcast_failure_does_not_raise
    task = @project.task_for_task_definition(@task_definition)

    ActionCable.server.stub(:broadcast, ->(*) { raise Redis::CannotConnectError }) do
      assert_nothing_raised { TaskChannel.broadcast_event(task, 'status_changed') }
    end
  end
end
