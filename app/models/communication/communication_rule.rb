class CommunicationRule < ApplicationRecord
  LOGICAL_OPERATORS = %w[and or].freeze

  belongs_to :communication_set, class_name: 'CommunicationSet'
  delegate :unit, to: :communication_set

  has_many :communication_conditions,
           class_name: 'CommunicationCondition',
           foreign_key: :communication_id,
           inverse_of: :communication,
           dependent: :destroy
  has_many :communication_actions, class_name: 'CommunicationAction', dependent: :destroy

  validates :name, presence: true
  validates :operator, presence: true, inclusion: { in: LOGICAL_OPERATORS }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def matching_projects(projects = nil)
    projects ||= communication_set.eligible_projects
    return projects if communication_conditions.empty?

    projects.select do |project|
      matches = communication_conditions.map do |condition|
        case condition.type
        when 'TargetGradeCondition'
          project_target_grade = project.target_grade
          next false if project_target_grade.nil?

          case condition.operator
          when 'greater_than' then project_target_grade > condition.target_grade
          when 'greater_than_or_equal_to' then project_target_grade >= condition.target_grade
          when 'less_than' then project_target_grade < condition.target_grade
          when 'less_than_or_equal_to' then project_target_grade <= condition.target_grade
          when 'equal_to' then project_target_grade == condition.target_grade
          when 'not_equal_to' then project_target_grade != condition.target_grade
          else false
          end
        when 'TaskDefinitionStatusCondition'
          task = project.tasks.find { |t| t.task_definition_id == condition.task_definition_id }
          status = task&.task_status&.status_key&.to_s
          statuses = condition.task_statuses || []

          case condition.operator
          when 'equal_to' then statuses.include?(status)
          when 'not_equal_to' then !statuses.include?(status)
          else false
          end
        when 'TaskStatusCountCondition'
          statuses = condition.task_statuses || []
          count = project.tasks.count do |task|
            task.task_definition&.target_grade == condition.task_target_grade &&
              statuses.include?(task.task_status&.status_key&.to_s)
          end

          case condition.operator
          when 'greater_than' then count > condition.task_status_count
          when 'greater_than_or_equal_to' then count >= condition.task_status_count
          when 'less_than' then count < condition.task_status_count
          when 'less_than_or_equal_to' then count <= condition.task_status_count
          when 'equal_to' then count == condition.task_status_count
          when 'not_equal_to' then count != condition.task_status_count
          else false
          end
        when 'LoginStatusCondition'
          last_sign_in_at = project.user&.last_sign_in_at

          case condition.operator
          when 'before' then last_sign_in_at.present? && last_sign_in_at < condition.last_sign_in_at
          when 'after' then last_sign_in_at.present? && last_sign_in_at > condition.last_sign_in_at
          else false
          end
        when 'TutorialEnrolmentCondition'
          enrolled = project.tutorial_enrolments.any? { |enrolment| enrolment.tutorial_id == condition.tutorial_id }

          condition.operator == 'not_enrolled_in' ? !enrolled : enrolled
        when 'TutorialStreamEnrolmentCondition'
          enrolled = project.tutorial_enrolments.any? do |enrolment|
            enrolment.tutorial&.tutorial_stream_id == condition.tutorial_stream_id
          end

          condition.operator == 'not_enrolled_in' ? !enrolled : enrolled
        when 'CampusCondition'
          enrolled = project.campus_id == condition.campus_id

          condition.operator == 'not_enrolled_in' ? !enrolled : enrolled
        else
          false
        end
      end

      operator == 'or' ? matches.any? : matches.all?
    end
  end
end
