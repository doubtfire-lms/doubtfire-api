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
      # A broken rule is shown in the preview as matching nobody so the editor
      # can still render the set, but the whole set stays unexecutable: this
      # allocation is a waterfall, and the students the rule would have consumed
      # now fall through to later rules, so every row below it is unreliable too.
      matched_projects = rule.unresolved? ? [] : rule.matching_projects(remaining_projects)
      allocations << { rule: rule, projects: matched_projects, unresolved: rule.unresolved? }
      return allocations if rule.id == target_rule.id

      remaining_projects -= matched_projects
    end

    allocations
  end

  # Rules that cannot be evaluated because they reference records missing from
  # this unit -- usually the result of an import, or of a task definition being
  # deleted after the rule was written.
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
        new_condition = copy_record_to(condition, other_unit)
        new_condition.communication = new_rule
        new_condition.save!
      end

      rule.communication_actions.each do |action|
        new_action = copy_record_to(action, other_unit)
        new_action.communication_rule = new_rule
        new_action.save!
      end
    end

    new_set
  end

  private

  # Rebuilds a condition or action against another unit. References resolve by
  # natural key where the target unit has an equivalent record; where it does
  # not, the reference is kept as a placeholder so the rule is flagged and
  # blocked rather than quietly matching the wrong students.
  def copy_record_to(record, other_unit)
    new_record = record.dup
    new_record.unresolved_references = nil

    CommunicationReferenceResolver.apply(
      new_record,
      CommunicationReferenceResolver.describe(record),
      other_unit
    )

    new_record
  end
end
