require 'test_helper'

#
# Contains tests for TaskDefinition model objects - not accessed via API
#
class StageModelTest < ActiveSupport::TestCase
  def app
    Rails.application
  end

  # Test that you can create a valid stage
  def test_stage_creation
    td = FactoryBot.create(:task_definition)
    stage = Stage.create(task_definition: td, title: 'Stage 1', order: 1)

    assert stage
    assert stage.task_definition
    assert stage.title == 'Stage 1'
    assert stage.order == 1
  end

  def test_stage_order_and_title_are_required
    td = FactoryBot.create(:task_definition)
    stage = Stage.new(task_definition: td)

    refute stage.valid?
    stage.title = 'Stage 1'
    refute stage.valid?
    stage.order = 1
    assert stage.valid?
    stage.title = nil
    refute stage.valid?

    refute stage.save
  end
end
