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
end
