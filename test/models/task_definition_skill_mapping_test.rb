require 'test_helper'

class TaskDefinitionSkillMappingTest < ActiveSupport::TestCase
  def test_rollover_keeps_the_unit_definition_and_task_skill_mappings
    unit = FactoryBot.create(:unit, teaching_period: TeachingPeriod.find(3), with_students: false, task_count: 1)
    definition = UnitDefinition.create!(code: unit.code, name: unit.name, version: 'rollover-test')
    unit.update!(unit_definition: definition)
    framework = SkillFramework.create!(code: 'ROLL', name: 'Rollover framework', version: '1')
    skill = Skill.create!(skill_framework: framework, code: 'PROG', name: 'Programming')
    level = SkillLevel.create!(skill: skill, name: 'Level 2', rank: 2)
    task_definition = unit.task_definitions.first
    task_definition.task_definition_skill_mappings.create!(skill: skill, skill_level: level)

    rolled = unit.rollover TeachingPeriod.find(2), nil, nil, nil

    assert_equal definition, rolled.unit_definition
    assert_equal level, rolled.task_definitions.find_by(abbreviation: task_definition.abbreviation)
                              .task_definition_skill_mappings.sole.skill_level
  ensure
    rolled&.destroy
    unit&.destroy
  end
end
