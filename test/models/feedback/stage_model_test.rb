require 'test_helper'

#
# Contains tests for Stage model objects - not accessed via API
#
class StageModelTest < ActiveSupport::TestCase

  # # Set up variables for testing
  setup do
    @td = FactoryBot.create(:task_definition)
    @title = Faker::Lorem.sentence
    @order = Faker::Number.number(digits: 1)
  end

  # Test that you can create a valid stage
  def test_valid_stage_creation
    DatabaseCleaner.start
    stage = Stage.create!(task_definition: @td, title: @title, order: @order)

    assert stage.valid? # "assert": pass if true, i.e. pass if stage exists
    assert_equal @td, stage.task_definition
    assert_equal @title, stage.title
    assert_equal @order, stage.order
  end

  # Test that you cannot create an invalid stage
  def test_invalid_stage_creation

    # Test that stage is invalid without task definition id
    stage = Stage.new(title: @title, order: @order)
    refute stage.valid? # pass if stage does not exist

    # Test that stage is invalid without title and order
    stage = Stage.new(task_definition: @td)
    refute stage.valid?

    # Test that stage is valid with both title and order
    stage.title = @title
    stage.order = @order
    assert stage.valid?

    # Test that stage is invalid with title and without order
    stage.order = nil
    refute stage.valid?
    assert_includes stage.errors[:order], "can't be blank"
  
    # Test that stage is invalid with order and without title
    stage.title = nil
    stage.order = @order
    refute stage.valid?
    assert_includes stage.errors[:title], "can't be blank"

    # Test that stage is unsaved
    refute stage.save # fail if stage is saved
  end
end