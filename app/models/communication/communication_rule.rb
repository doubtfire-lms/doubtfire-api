class CommunicationRule < ApplicationRecord
  LOGICAL_OPERATORS = %w[and or].freeze

  belongs_to :communication_set, class_name: 'CommunicationSet'
  delegate :unit, :unit_id, to: :communication_set

  has_many :communication_conditions,
           class_name: 'CommunicationCondition',
           foreign_key: :communication_id,
           inverse_of: :communication,
           dependent: :destroy
  has_many :communication_actions, class_name: 'CommunicationAction', dependent: :destroy

  validates :name, presence: true
  validates :operator, presence: true, inclusion: { in: LOGICAL_OPERATORS }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def unresolved_records
    (communication_conditions.to_a + communication_actions.to_a).select(&:unresolved?)
  end

  def unresolved?
    unresolved_records.any?
  end

  def matching_projects(projects = nil)
    # Only reached by the editor preview -- ExecuteCommunicationSetJob refuses
    # the whole set before any rule runs, so nothing is sent on the back of this.
    return [] if unresolved?

    projects ||= communication_set.eligible_projects
    return projects if communication_conditions.empty?

    evaluated_at = Time.current
    projects.select do |project|
      matches = communication_conditions.map { |condition| condition_match?(project, condition, evaluated_at) }

      operator == 'or' ? matches.any? : matches.all?
    end
  end

  private

  def condition_match?(project, condition, evaluated_at)
    case condition.type
    when 'TargetGradeCondition'
      target_grade_condition_match?(project, condition)
    when 'TaskDefinitionStatusCondition'
      task_definition_status_condition_match?(project, condition)
    when 'TaskStatusCountCondition'
      task_status_count_condition_match?(project, condition)
    when 'LoginStatusCondition'
      activity_condition_match?(project.user&.last_sign_in_at, condition, evaluated_at)
    when 'UnitViewedStatusCondition'
      activity_condition_match?(project.last_viewed_at, condition, evaluated_at)
    when 'SpecConCondition'
      spec_con_condition_match?(project, condition)
    when 'TutorialEnrolmentCondition'
      tutorial_enrolment_condition_match?(project, condition)
    when 'TutorialStreamEnrolmentCondition'
      tutorial_stream_enrolment_condition_match?(project, condition)
    when 'CampusCondition'
      campus_condition_match?(project, condition)
    when 'PortfolioSubmittedCondition'
      portfolio_submitted_condition_match?(project, condition)
    else
      false
    end
  end

  def target_grade_condition_match?(project, condition)
    project_target_grade = project.target_grade
    return false if project_target_grade.nil?

    compare_value(project_target_grade, condition.target_grade, condition.operator)
  end

  def task_definition_status_condition_match?(project, condition)
    task = project.tasks.find { |t| t.task_definition_id == condition.task_definition_id }
    status = task&.task_status&.status_key&.to_s || 'not_started'
    statuses = condition.task_statuses || []

    case condition.operator
    when 'equal_to' then statuses.include?(status)
    when 'not_equal_to' then !statuses.include?(status)
    else false
    end
  end

  def task_status_count_condition_match?(project, condition)
    statuses = condition.task_statuses || []
    relevant_task_definitions = project.unit.task_definitions.select do |task_definition|
      task_definition.target_grade == condition.task_target_grade
    end

    count = relevant_task_definitions.count do |task_definition|
      task = project.tasks.find { |project_task| project_task.task_definition_id == task_definition.id }
      task_status = task&.task_status&.status_key&.to_s || 'not_started'

      statuses.include?(task_status)
    end

    compare_value(count, condition.task_status_count, condition.operator)
  end

  def activity_condition_match?(last_activity_at, condition, evaluated_at)
    return false if condition.activity_days.blank?

    threshold = evaluated_at - condition.activity_days.days
    case condition.operator
    when 'more_than' then last_activity_at.nil? || last_activity_at < threshold
    when 'within_last' then last_activity_at.present? && last_activity_at >= threshold
    else false
    end
  end

  def spec_con_condition_match?(project, condition)
    compare_value(project.spec_con_days, condition.spec_con_days, condition.operator)
  end

  def tutorial_enrolment_condition_match?(project, condition)
    enrolled = project.tutorial_enrolments.any? { |enrolment| enrolment.tutorial_id == condition.tutorial_id }

    condition.operator == 'not_enrolled_in' ? !enrolled : enrolled
  end

  def tutorial_stream_enrolment_condition_match?(project, condition)
    enrolled = project.tutorial_enrolments.any? do |enrolment|
      enrolment.tutorial&.tutorial_stream_id == condition.tutorial_stream_id
    end

    condition.operator == 'not_enrolled_in' ? !enrolled : enrolled
  end

  def campus_condition_match?(project, condition)
    enrolled = project.campus_id == condition.campus_id

    condition.operator == 'not_enrolled_in' ? !enrolled : enrolled
  end

  def portfolio_submitted_condition_match?(project, condition)
    project.portfolio_exists? == condition.submitted_portfolio
  end

  def compare_value(left, right, operator)
    case operator
    when 'greater_than' then left > right
    when 'greater_than_or_equal_to' then left >= right
    when 'less_than' then left < right
    when 'less_than_or_equal_to' then left <= right
    when 'equal_to' then left == right
    when 'not_equal_to' then left != right
    else false
    end
  end
end
