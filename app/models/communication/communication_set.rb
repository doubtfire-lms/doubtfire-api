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

  # Memoised so a request loads the student data once, not once per rule.
  def eligible_projects
    @eligible_projects ||=
      unit.projects
          .where(enrolled: true)
          .includes(
            :user,
            :campus,
            { unit: :task_definitions },
            { tasks: [:task_status, :task_definition] },
            { tutorial_enrolments: :tutorial }
          )
          .to_a
  end

  def eligible_project_count
    unit.projects.where(enrolled: true).count
  end

  # Matching is a pure per-project predicate, so the set's cascade is exactly
  # these matches minus the students earlier rules claimed. Lets callers
  # evaluate one rule at a time instead of re-running the set.
  def independent_matches_for_rule(target_rule)
    target_rule.matching_projects(eligible_projects)
  end

  def preview_projects_for_rule(target_rule)
    preview_allocations_for_rule(target_rule)
      .find { |allocation| allocation[:rule].id == target_rule.id }
      &.fetch(:projects, []) || []
  end

  def preview_allocations_by_rule
    allocations = []
    remaining_projects = eligible_projects

    communication_rules.each_with_object({}) do |rule, allocations_by_rule|
      matched_projects = rule.matching_projects(remaining_projects)
      allocations << { rule: rule, projects: matched_projects }
      allocations_by_rule[rule.id] = allocations.dup
      remaining_projects -= matched_projects
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

  def unresolved_rules
    communication_rules.select(&:unresolved?)
  end

  def executable?
    unresolved_rules.empty?
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
        new_action.task_definition = matching_task_definition(other_unit, action)
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
