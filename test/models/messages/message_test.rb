require "test_helper"

class MessageTest < ActiveSupport::TestCase

  def test_can_create_a_test_message
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user

    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)

    comment1 = task.add_text_comment(convenor, 'Hello World')
    assert comment1.valid?
  end

  def test_only_one_last_message_read
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user

    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)

    comment1 = TaskComment.create(user: user, task: task, comment: 'Message 1', content_type: :text, recipient: convenor)
    comment2 = TaskComment.create(user: user, task: task, comment: 'Message 2', content_type: :text, recipient: convenor)

    lmr1 = LastMessageRead.create(user: user, message: comment1, context_id: task.id, context_type: 0, read_at: Time.now)
    assert lmr1.valid?

    lmr2 = LastMessageRead.create(user: user, message: comment2, context_id: task.id, context_type: 0, read_at: Time.now)
    refute lmr2.valid?
    refute lmr2.persisted?
    assert lmr1.persisted?

    # todo: test for validation
  end

end
