require 'test_helper'

class LearningOutcomeModelTest < ActiveSupport::TestCase

  def test_length_of_learning_outcome_fields
    learning_outcome = FactoryBot.build(:learning_outcome, short_description: 'a' * 100, full_outcome_description: 'a' * 1000, abbreviation: 'a' * 5)
    assert learning_outcome.valid?, learning_outcome.errors.full_messages

    learning_outcome.short_description = 'a' * 101
    assert_not learning_outcome.valid?
    assert_includes learning_outcome.errors.full_messages, 'Short description is too long (maximum is 100 characters)'

    learning_outcome.short_description = 'a' * 100
    learning_outcome.abbreviation = 'a' * 6
    assert_not learning_outcome.valid?
    assert_includes learning_outcome.errors.full_messages, 'Abbreviation is too long (maximum is 5 characters)'
  end

  def test_linking_learning_outcomes
    glo = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil)
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, outcome_count: 2)
    ulo = unit.learning_outcomes.first
    ulo2 = unit.learning_outcomes.last
    td = FactoryBot.create(:task_definition, unit: unit, outcome_count: 2)
    tlo = td.learning_outcomes.first
    tlo2 = td.learning_outcomes.last

    ulo.update_linked_outcomes([])
    ulo2.update_linked_outcomes([])
    tlo2.update_linked_outcomes(nil)
    tlo.update_linked_outcomes([glo.id, ulo.id])

    assert tlo.valid?, tlo.errors.full_messages
    assert_equal 2, tlo.outgoing_links.count
    assert_equal 1, ulo.demonstrated_through_outcome_links.count
    assert_equal 1, glo.demonstrated_through_outcome_links.count

    tlo.update_linked_outcomes([glo.id])

    assert tlo.valid?, tlo.errors.full_messages
    assert_equal 1, tlo.outgoing_links.count
    assert_equal 0, ulo.demonstrated_through_outcome_links.count
    assert_equal 0, ulo2.demonstrated_through_outcome_links.count
    assert_equal 1, glo.demonstrated_through_outcome_links.count

    tlo.update_linked_outcomes([ulo.id, ulo2.id])

    assert tlo.valid?, tlo.errors.full_messages
    assert_equal 2, tlo.outgoing_links.count
    assert_equal 1, ulo.demonstrated_through_outcome_links.count
    assert_equal 1, ulo2.demonstrated_through_outcome_links.count
    assert_equal 0, glo.demonstrated_through_outcome_links.count

    # Test ULO
    tlo.update_linked_outcomes([glo.id, ulo.id])
    ulo.update_linked_outcomes([glo.id])

    assert ulo.valid?, ulo.errors.full_messages
    assert_equal 1, ulo.outgoing_links.count
    assert_equal 0, tlo.demonstrated_through_outcome_links.count
    assert_equal 1, ulo.demonstrated_through_outcome_links.count
    assert_equal 2, glo.demonstrated_through_outcome_links.count

    # Test broken link direction
    ulo.update_linked_outcomes([glo.id, tlo.id, ulo2])
    assert_equal 0, tlo.demonstrated_through_outcome_links.count
    assert_equal 1, ulo.demonstrated_through_outcome_links.count

    tlo.update_linked_outcomes([tlo2.id, tlo.id])
    assert_equal 0, tlo.demonstrated_through_outcome_links.count

    ulo.update_linked_outcomes([ulo2.id, ulo.id])
    assert_equal 0, ulo.demonstrated_through_outcome_links.count

    glo.update_linked_outcomes([glo.id, ulo.id, tlo.id])
    assert_equal 0, glo.demonstrated_through_outcome_links.count

    # test no valid target
    tlo.update_linked_outcomes([-1])
    assert_equal 0, tlo.demonstrated_through_outcome_links.count
    assert_equal 0, tlo.outgoing_links.count
  end
end
