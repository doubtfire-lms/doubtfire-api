require 'task_serializer'

# Shallow serialization is used for student...
class ShallowProjectSerializer < ActiveModel::Serializer
  attributes :unit_id, :unit_code, :unit_name,
             :project_id, :student_name,
             :tutor_name, :target_grade,
             :has_portfolio, :start_date, :teaching_period

  def project_id
    object.id
  end

  def teaching_period
    if object.unit.teaching_period_id.present?
      teachingPeriod = TeachingPeriod.find(object.unit.teaching_period_id)
      ::TeachingPeriodSerializer.new(teachingPeriod).attributes
    end
  end
end

class ProjectSerializer < ActiveModel::Serializer
  attributes :unit_id,
             :project_id,
             :student_id,
             :started,
             :stats,
             :student_name,
             :tutor_name,
             :tutorial_id,
             :burndown_chart_data,
             :enrolled,
             :target_grade,
             :portfolio_files,
             :compile_portfolio,
             :portfolio_available,
             :grade,
             :grade_rationale,
             :tasks

  def project_id
    object.id
  end

  def student_name
    "#{object.student.name}#{object.student.nickname.nil? ? '' : ' (' << object.student.nickname << ')'}"
  end

  def student_id
    object.student.username
  end

  def tutor_name
    object.main_tutor.first_name unless object.main_tutor.nil?
  end

  def stats
    object.task_stats
  end

  def tasks
    object.task_details_for_shallow_serializer(Thread.current[:user])
  end

  has_many :groups, serializer: GroupSerializer
  has_many :task_outcome_alignments, serializer: LearningOutcomeTaskLinkSerializer

  def my_role_obj
    object.role_for(Thread.current[:user]) if Thread.current[:user]
  end

  def include_grade?
    ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? my_role_obj)
  end

  def include_grade_rationale?
    ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? my_role_obj)
  end

  def filter(keys)
    keys.delete :grade unless include_grade?
    keys.delete :grade_rationale unless include_grade_rationale?
    keys
  end
end

class GroupMemberProjectSerializer < ActiveModel::Serializer
  attributes :student_id, :project_id, :student_name, :target_grade

  def project_id
    object.id
  end

  def student_id
    object.student.username
  end

  def student_name
    "#{object.student.name}#{object.student.nickname.nil? ? '' : ' (' << object.student.nickname << ')'}"
  end

  def my_role_obj
    object.role_for(Thread.current[:user]) if Thread.current[:user]
  end

  def include_student_id?
    ([ Role.convenor, Role.tutor, :tutor, :convenor ].include? my_role_obj)
  end

  def filter(keys)
    keys.delete :student_id unless include_student_id?
    keys
  end
end
