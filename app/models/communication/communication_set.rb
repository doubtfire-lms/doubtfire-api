class CommunicationSet < ApplicationRecord
  belongs_to :unit

  has_many :communication_set_schedules,
           class_name: 'CommunicationSetSchedule',
           inverse_of: :communication_set,
           dependent: :destroy

  has_many :communication_rules,
           -> { order(:position) },
           class_name: 'CommunicationRule',
           inverse_of: :communication_set,
           dependent: :destroy

  validates :name, presence: true

  def eligible_projects
    unit.projects
        .where(enrolled: true)
        .includes(:user, :campus, { tasks: [:task_status, :task_definition] }, { tutorial_enrolments: :tutorial })
        .to_a
  end

  def preview_projects_for_rule(target_rule)
    preview_allocations_for_rule(target_rule)
      .find { |allocation| allocation[:rule].id == target_rule.id }
      &.fetch(:projects, []) || []
  end

  def preview_allocations_by_rule
    communication_rules.each_with_object({}) do |rule, allocations_by_rule|
      allocations_by_rule[rule.id] = preview_allocations_for_rule(rule)
    end
  end

  def preview_allocations_for_rule(target_rule)
    remaining_projects = eligible_projects
    allocations = []

    communication_rules.each do |rule|
      matched_projects = rule.matching_projects(remaining_projects)
      allocations << { rule: rule, projects: matched_projects }
      return allocations if rule.id == target_rule.id

      remaining_projects -= matched_projects
    end

    allocations
  end

  def copy_to(other_unit)
    new_set = dup
    new_set.unit = other_unit
    new_set.save!

    communication_set_schedules.each do |schedule|
      new_schedule = schedule.dup
      new_schedule.communication_set = new_set
      new_schedule.ice_cube_schedule = nil
      new_schedule.next_run_at = nil
      new_schedule.last_run_at = nil
      new_schedule.last_enqueued_at = nil
      new_schedule.save!
    end

    communication_rules.each do |rule|
      new_rule = rule.dup
      new_rule.communication_set = new_set
      new_rule.save!

      rule.communication_conditions.each do |condition|
        new_condition = condition.dup
        new_condition.communication = new_rule
        new_condition.task_definition = matching_task_definition(other_unit, condition)
        new_condition.tutorial_stream = matching_tutorial_stream(other_unit, condition)
        new_condition.tutorial = matching_tutorial(other_unit, condition)
        new_condition.save!
      end

      rule.communication_actions.each do |action|
        new_action = action.dup
        new_action.communication_rule = new_rule
        new_action.save!
      end
    end

    new_set
  end

  private

  def matching_task_definition(unit, condition)
    return nil if condition.task_definition.blank?

    unit.task_definitions.find_by(abbreviation: condition.task_definition.abbreviation)
  end

  def matching_tutorial_stream(unit, condition)
    return nil if condition.tutorial_stream.blank?

    unit.tutorial_streams.find_by(abbreviation: condition.tutorial_stream.abbreviation)
  end

  def matching_tutorial(unit, condition)
    return nil if condition.tutorial.blank?

    unit.tutorials.find_by(
      abbreviation: condition.tutorial.abbreviation,
      campus_id: condition.tutorial.campus_id
    )
  end
end
