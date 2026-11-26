require 'test_helper'

class FeedbackChipModelTest < ActiveSupport::TestCase

  def test_csv_context_uses_import_unit_and_task_context
    previous_period = FactoryBot.create(:teaching_period)
    current_period = FactoryBot.create(:teaching_period)
    previous_unit = FactoryBot.create(:unit, code: 'SAME1', teaching_period: previous_period, task_count: 0, outcome_count: 0)
    current_unit = FactoryBot.create(:unit, code: 'SAME1', teaching_period: current_period, task_count: 0, outcome_count: 0)
    FactoryBot.create(:task_definition, unit: previous_unit, abbreviation: 'T1', outcome_count: 0)
    current_task = FactoryBot.create(:task_definition, unit: current_unit, abbreviation: 'T1', outcome_count: 0)
    unit_outcome = FactoryBot.create(:learning_outcome, context: current_unit, abbreviation: 'LO1')
    task_outcome = FactoryBot.create(:learning_outcome, context: current_task, abbreviation: 'LO1')
    row = CSV::Row.new(
      %w[unit_code task_abbreviation learning_outcome_abbreviation],
      %w[SAME1 T1 LO1]
    )

    result = Feedback::FeedbackChip.context_for_csv(row, 'Unit', current_unit)

    assert result[:success]
    assert_equal current_unit, result[:unit]
    assert_equal current_task, result[:task_definition]
    assert_equal task_outcome, result[:learning_outcome]
    assert_not_equal unit_outcome, result[:learning_outcome]
  end

  def test_valid_feedback_template_chip_parent
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    parent_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    feedback_template_chip = FactoryBot.build(:feedback_template_chip, parent_chip_id: parent_chip.id, learning_outcome_id: learning_outcome.id)
    assert feedback_template_chip.valid?
    assert parent_chip.valid?
  end

  def test_invalid_feedback_template_chip_parent
    other_learning_outcome = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil)
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    parent_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: other_learning_outcome.id)
    feedback_template_chip = FactoryBot.build(:feedback_template_chip, parent_chip_id: parent_chip.id, learning_outcome_id: learning_outcome.id)

    assert parent_chip.valid?
    assert_not feedback_template_chip.valid?
    assert_includes feedback_template_chip.errors.full_messages, 'Parent chip must be in the same learning outcome'
  end

  def test_valid_parent_is_group_chip
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    group_chip = FactoryBot.create(:feedback_group_chip, parent_chip_id: nil, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, parent_chip_id: group_chip.id, learning_outcome_id: learning_outcome.id)
    template_chip2 = FactoryBot.build(:feedback_template_chip, parent_chip_id: template_chip.id, learning_outcome_id: learning_outcome.id) # tests for parent is group chip // parent is not group chip
    assert_not template_chip2.valid?
    assert_includes template_chip2.errors.full_messages, 'Parent chip must be a group chip'
  end

  def test_no_circular_parent_child_relationship
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    group_chips = []
    group_chips << FactoryBot.create(:feedback_group_chip, parent_chip_id: nil, learning_outcome_id: learning_outcome.id)
    group_chips << FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chips[0].id, learning_outcome_id: learning_outcome.id)
    group_chips << FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chips[1].id, learning_outcome_id: learning_outcome.id)
    group_chips << FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chips[2].id, learning_outcome_id: learning_outcome.id)
    group_chips << FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chips[3].id, learning_outcome_id: learning_outcome.id)

    group_chips.each { |gc| assert gc.valid?, gc.inspect }

    group_chips[0].parent_chip_id = group_chips[4].id
    assert_not group_chips[0].valid?
    assert_includes group_chips[0].errors.full_messages, 'Parent chip cannot create a loop'
  end

  def test_can_delete_parent_chip
    unit = Unit.first
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    group_chips = []
    group_chips << FactoryBot.create(:feedback_group_chip, parent_chip_id: nil, learning_outcome_id: learning_outcome.id)
    group_chips << FactoryBot.create(:feedback_group_chip, parent_chip_id: group_chips[0].id, learning_outcome_id: learning_outcome.id)

    template_chips = [
      FactoryBot.create(:feedback_template_chip, parent_chip_id: group_chips[0].id, learning_outcome_id: learning_outcome.id),
      FactoryBot.create(:feedback_template_chip, parent_chip_id: group_chips[0].id, learning_outcome_id: learning_outcome.id),
      FactoryBot.create(:feedback_template_chip, parent_chip_id: group_chips[1].id, learning_outcome_id: learning_outcome.id),
      FactoryBot.create(:feedback_template_chip, parent_chip_id: group_chips[1].id, learning_outcome_id: learning_outcome.id)
    ]

    group_chips[0].destroy

    assert group_chips[0].destroyed?
    assert_not group_chips[1].destroyed?
    assert_nil group_chips[1].reload.parent_chip_id

    [template_chips[0], template_chips[1]].each do |tc|
      assert_not tc.destroyed?
      assert_nil tc.reload.parent_chip_id
    end

    [template_chips[2], template_chips[3]].each do |tc|
      assert_not tc.destroyed?
      assert_equal group_chips[1].id, tc.reload.parent_chip_id
    end
  end
end
