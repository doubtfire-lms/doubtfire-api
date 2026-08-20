class CommunicationCondition < ApplicationRecord
  VALID_TYPES = %w[
    TargetGradeCondition
    TaskDefinitionStatusCondition
    TaskStatusCountCondition
    LoginStatusCondition
    UnitViewedStatusCondition
    SpecConCondition
    TutorialEnrolmentCondition
    TutorialStreamEnrolmentCondition
    CampusCondition
    PortfolioSubmittedCondition
  ].freeze

  GRADE_OPERATORS = %w[
    greater_than
    greater_than_or_equal_to
    less_than
    less_than_or_equal_to
    equal_to
    not_equal_to
  ].freeze

  EQUALITY_OPERATORS = %w[equal_to not_equal_to].freeze
  ACTIVITY_OPERATORS = %w[more_than within_last].freeze
  ENROLMENT_OPERATORS = %w[enrolled_in not_enrolled_in].freeze
  TASK_STATUS_KEYS = %w[
    not_started
    complete
    need_help
    working_on_it
    fix_and_resubmit
    feedback_exceeded
    redo
    discuss
    ready_for_feedback
    demonstrate
    fail
    time_exceeded
    assess_in_portfolio
    attention_required
    rediscuss
  ].freeze

  REQUIRED_REFERENCES = {
    'TaskDefinitionStatusCondition' => :task_definition,
    'TutorialEnrolmentCondition' => :tutorial,
    'TutorialStreamEnrolmentCondition' => :tutorial_stream,
    'CampusCondition' => :campus
  }.freeze

  belongs_to :communication,
             class_name: 'CommunicationRule',
             inverse_of: :communication_conditions

  belongs_to :task_definition, optional: true
  belongs_to :tutorial, optional: true
  belongs_to :tutorial_stream, optional: true
  belongs_to :campus, optional: true

  attribute :task_statuses, :json, default: -> { [] }

  validates :type, presence: true, inclusion: { in: VALID_TYPES }
  validates :operator, presence: true
  before_validation :normalize_task_statuses

  def required_reference
    REQUIRED_REFERENCES[type]
  end

  # A missing reference cannot be left to evaluate: an absent task definition
  # reads as 'not_started' for every student, widening the rule instead of
  # narrowing it.
  def unresolved?
    reference = required_reference
    return false if reference.nil?

    target = public_send(reference)
    return true if target.blank?

    # Campuses are shared between units; everything else must be our own.
    target.respond_to?(:unit_id) && target.unit_id != communication.unit_id
  end

  def task_statuses_must_be_present
    unless task_statuses.is_a?(Array) && task_statuses.any?(&:present?)
      errors.add(:task_statuses, 'must include at least one task status')
      return
    end

    invalid_statuses = task_statuses.reject { |status| TASK_STATUS_KEYS.include?(status) }
    return if invalid_statuses.empty?

    errors.add(:task_statuses, "contains invalid task statuses: #{invalid_statuses.join(', ')}")
  end

  private

  def normalize_task_statuses
    parsed_statuses =
      case task_statuses
      when nil
        nil
      when String
        begin
          JSON.parse(task_statuses)
        rescue JSON::ParserError
          [task_statuses]
        end
      when Array
        task_statuses
      else
        Array(task_statuses)
      end

    self.task_statuses =
      parsed_statuses&.filter_map do |status|
        status.is_a?(String) ? status.strip.presence : status.presence
      end
  end
end
