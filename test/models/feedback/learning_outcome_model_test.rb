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

  def test_export_learning_outcomes
    unit = FactoryBot.create :unit, task_count: 0, with_students: false, outcome_count: 1

    glo = FactoryBot.create :learning_outcome, context_type: nil, context_id: nil
    ulo = unit.learning_outcomes.first

    td = FactoryBot.create :task_definition, outcome_count: 4, unit: unit

    td.learning_outcomes.first.update_linked_outcomes([glo, ulo])
    td.learning_outcomes.second.update_linked_outcomes([ulo])
    td.learning_outcomes.last.update_linked_outcomes([glo])

    csv = td.export_learning_outcome_to_csv(include_tlos: true)
    assert_equal 1 + td.learning_outcomes.count, csv.split("\n").length, csv

    td.learning_outcomes.each do |lo|
      assert_includes csv, lo.short_description
      assert_includes csv, lo.full_outcome_description
      assert_includes csv, lo.abbreviation
      assert_includes csv, lo.linked_outcomes.pluck(:abbreviation).join(',')
    end

    csv = unit.export_learning_outcome_to_csv(include_tlos: false)
    assert_equal 1 + unit.learning_outcomes.count, csv.split("\n").length, csv

    unit.learning_outcomes.each do |lo|
      assert_includes csv, lo.short_description
      assert_includes csv, lo.full_outcome_description
      assert_includes csv, lo.abbreviation
      assert_includes csv, lo.linked_outcomes.pluck(:abbreviation).join(',')
    end

    csv = unit.export_learning_outcome_to_csv(include_tlos: true)
    assert_equal 1 + unit.learning_outcomes.count + td.learning_outcomes.count, csv.split("\n").length, csv

    [unit.learning_outcomes, td.learning_outcomes].flatten.each do |lo|
      assert_includes csv, lo.short_description
      assert_includes csv, lo.full_outcome_description
      assert_includes csv, lo.abbreviation
      assert_includes csv, lo.linked_outcomes.pluck(:abbreviation).join(',')
    end
  end

  def test_create_from_csv
    tmp_file = Tempfile.new('test-outcomes.csv')
    unit = FactoryBot.create :unit, task_count: 0, with_students: false, outcome_count: 0
    td = FactoryBot.create :task_definition, outcome_count: 0, unit: unit

    glo = FactoryBot.create :learning_outcome, context_type: nil, context_id: nil, abbreviation: 'GLO**'
    ulo = FactoryBot.create :learning_outcome, context_type: 'Unit', context_id: unit.id, abbreviation: 'ULO**'
    tlo = FactoryBot.create :learning_outcome, context_type: 'TaskDefinition', context_id: td.id, abbreviation: 'TLO**'

    tlo.update_linked_outcomes([glo.id, ulo.id])
    ulo.update_linked_outcomes([glo.id])

    csv = unit.export_learning_outcome_to_csv(include_tlos: true)
    File.write(tmp_file, csv)

    # new version of the unit
    new_unit = FactoryBot.create :unit, task_count: 0, with_students: false, outcome_count: 0, code: unit.code, start_date: unit.start_date, end_date: unit.end_date + 2.weeks
    td = FactoryBot.create :task_definition, outcome_count: 0, unit: new_unit, abbreviation: td.abbreviation

    result = new_unit.import_outcomes_from_csv(tmp_file.path)

    assert_equal unit.learning_outcomes.count, new_unit.learning_outcomes.count, result

    new_ulo = new_unit.learning_outcomes.find_by(abbreviation: ulo.abbreviation)
    assert_not_nil new_ulo
    assert_equal ulo.full_outcome_description, new_ulo.full_outcome_description
    assert_equal ulo.short_description, new_ulo.short_description
    assert_equal 1, new_ulo.linked_outcomes.pluck(:id).count
    assert_includes new_ulo.linked_outcomes.pluck(:id), glo.id

    new_tlo = new_unit.task_definitions.first.learning_outcomes.find_by(abbreviation: tlo.abbreviation)
    assert_not_nil new_tlo
    assert_equal tlo.full_outcome_description, new_tlo.full_outcome_description
    assert_equal tlo.short_description, new_tlo.short_description
    assert_equal 2, new_tlo.linked_outcomes.pluck(:id).count, new_tlo.linked_outcomes.map{ |o| "#{o.id} #{o.abbreviation}" }.join(',')
    assert_includes new_tlo.linked_outcomes.pluck(:id), glo.id
    assert_includes new_tlo.linked_outcomes.pluck(:id), new_ulo.id
  ensure
    FileUtils.rm_f(Rails.root.join('tmp/test-outcomes.csv'))
  end
end
