require 'test_helper'

#
# Contains tests for Stage model objects - not accessed via API
#
class StageModelTest < ActiveSupport::TestCase
  def app
    Rails.application
  end

  # Test that you can create a valid stage
  def test_stage_creation
    td = FactoryBot.create(:task_definition) # FactoryBot is a gem that creates test data
    stage = Stage.create(task_definition: td, title: 'Stage 1', order: 1)

    assert stage # "assert": pass if true, i.e. pass if stage exists
    assert stage.task_definition # test that stage has a task definition
    assert stage.title == 'Stage 1' # test that the stage has the correct title, i.e. 'Stage 1'
    assert stage.order == 1 # test that the stage has the correct order, i.e. 1
  end

  # Test that you cannot create an invalid stage
  def test_stage_order_and_title_are_required
    td = FactoryBot.create(:task_definition)
    stage = Stage.new(task_definition: td)

    refute stage.valid? # "refute": fail if true, i.e. fail if stage is valid
    # Validator is included 
    stage.title = 'Stage 1'
    refute stage.valid?
    stage.order = 1
    assert stage.valid?
    stage.title = nil
    refute stage.valid?

    refute stage.save # fail if stage is saved
  end
end
