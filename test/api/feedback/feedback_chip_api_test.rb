require 'test_helper'

class FeedbackChipApiTest < ActiveSupport::TestCase

  def test_valid_feedback_template_chip_parent
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    parent_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    feedback_template_chip = FactoryBot.build(:feedback_template_chip, parent_chip_id: parent_chip.id, learning_outcome_id: learning_outcome.id)
    assert feedback_template_chip.valid?
  end

  def test_invalid_feedback_template_chip_parent
    feedback_template_chip = FactoryBot.build(:feedback_template_chip, parent_chip_id: nil)
    assert_not feedback_template_chip.valid?
  end

  def test_valid_parent_is_group_chip
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    group_chip = FactoryBot.create(:feedback_group_chip, parent_chip_id: nil, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, parent_chip_id: group_chip.id, learning_outcome_id: learning_outcome.id)
    template_chip_2 = FactoryBot.build(:feedback_template_chip, parent_chip_id: template_chip.id, learning_outcome_id: learning_outcome.id) # tests for parent is group chip // parent is not group chip
    assert_not template_chip_2.valid?
    assert_includes template_chip_2.errors.full_messages, 'Parent chip must be a group chip'
  end

  def test_no_circular_parent_child_relationship
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    group_chip = FactoryBot.create(:feedback_group_chip, parent_chip_id: nil, learning_outcome_id: learning_outcome.id)
    group_chip_nested_1 = FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chip.id, learning_outcome_id: learning_outcome.id)
    group_chip_nested_2 = FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chip_nested_1.id, learning_outcome_id: learning_outcome.id)
    group_chip_nested_3 = FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chip_nested_2.id, learning_outcome_id: learning_outcome.id)
    group_chip_nested_4 = FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chip_nested_3.id, learning_outcome_id: learning_outcome.id)
    group_chip.parent_chip_id = group_chip_nested_4.id
    assert_not group_chip.valid?
    assert_includes group_chip.errors.full_messages, 'Parent chip cannot create a loop'
  end

  def test_valid_group_chip_as_root
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    root_chip = FactoryBot.create(:feedback_group_chip, parent_chip: nil, learning_outcome_id: learning_outcome.id)
    assert root_chip.valid?
  end

=begin
  def test_single_root_chip_per_learning_outcome
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    root_chip_1 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: nil)
    root_chip_2 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: nil)

    assert_not root_chip_2.valid?
    assert_includes root_chip_2.errors.full_messages, 'Only one root chip allowed per learning outcome'
  end
=end

  def test_tree_completeness_for_learning_outcome
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    root_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: nil)
    group_chip_1 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: root_chip.id)
    group_chip_2 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: root_chip.id)
    template_chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip_1.id)

    orphaned_chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip_2.id)
    orphaned_chip.parent_chip_id = nil

    assert_not orphaned_chip.valid?
    assert_includes orphaned_chip.errors.full_messages, 'Tree is not complete for the learning outcome; some chips are orphaned and unreachable'
  end
end
