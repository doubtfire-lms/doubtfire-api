require 'grape'
require 'entities/communication_set_entity'
require 'entities/communication_rule_entity'
require 'entities/communication_condition_entity'
require 'entities/communication_action_entity'
require 'entities/sidekiq_job_entity'

class CommunicationRulesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers SidekiqHelper

  before do
    authenticated?
  end

  desc 'Get communication sets for a unit'
  params do
    requires :unit_id, type: Integer
  end
  get '/units/:unit_id/communication_sets' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    present unit.communication_sets.includes(communication_rules: [:communication_conditions, :communication_actions]),
            with: Entities::CommunicationSetEntity
  end

  desc 'Get a communication set for a unit with preview data'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  get '/units/:unit_id/communication_sets/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_students
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    communication_set = unit.communication_sets
                            .includes(communication_rules: [:communication_conditions, :communication_actions])
                            .find(params[:id])

    previews = communication_set.preview_allocations_by_rule

    present(
      id: communication_set.id,
      unit_id: communication_set.unit_id,
      name: communication_set.name,
      active: communication_set.active,
      rules: Entities::CommunicationRuleEntity.represent(communication_set.communication_rules),
      previews: communication_set.communication_rules.map do |rule|
        {
          target_rule_id: rule.id,
          allocations: previews.fetch(rule.id, []).map do |allocation|
            {
              rule_id: allocation[:rule].id,
              rule_name: allocation[:rule].name,
              position: allocation[:rule].position,
              students: allocation[:projects].map do |project|
                {
                  first_name: project.user&.first_name,
                  last_name: project.user&.last_name,
                  preferred_name: project.user&.nickname,
                  username: project.user&.username,
                  student_id: project.user&.student_id,
                  full_name: [project.user&.first_name, project.user&.last_name].compact.join(' '),
                  target_grade: project.target_grade,
                  last_sign_in_at: project.user&.last_sign_in_at,
                  campus: project.campus&.name
                }
              end
            }
          end
        }
      end
    )
  end

  desc 'Create a communication set for a unit'
  params do
    requires :unit_id, type: Integer
    requires :communication_set, type: Hash do
      requires :name, type: String
      optional :active, type: Boolean
    end
  end
  post '/units/:unit_id/communication_sets' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    set_params = ActionController::Parameters.new(params)
                                             .require(:communication_set)
                                             .permit(:name, :active)

    communication_set = unit.communication_sets.create!(set_params)
    present communication_set, with: Entities::CommunicationSetEntity
  end

  desc 'Update a communication set'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
    requires :communication_set, type: Hash do
      optional :name, type: String
      optional :active, type: Boolean
    end
  end
  put '/units/:unit_id/communication_sets/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:id])
    set_params = ActionController::Parameters.new(params)
                                             .require(:communication_set)
                                             .permit(:name, :active)

    communication_set.update!(set_params)
    present communication_set, with: Entities::CommunicationSetEntity
  end

  desc 'Delete a communication set'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  delete '/units/:unit_id/communication_sets/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    unit.communication_sets.find(params[:id]).destroy!
    status 204
  end

  desc 'Execute a communication set'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  post '/units/:unit_id/communication_sets/:id/execute' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to execute unit communications' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:id])
    job_id = ExecuteCommunicationSetJob.perform_async(communication_set.id)
    job = setup_job(job_id)

    present job, with: Entities::SidekiqJobEntity
  end

  desc 'Get communication rules for a unit'
  params do
    requires :unit_id, type: Integer
  end
  get '/units/:unit_id/communication_rules' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    present unit.communication_rules.includes(:communication_conditions, :communication_actions),
            with: Entities::CommunicationRuleEntity
  end

  desc 'Get communication rules for a set'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
  end
  get '/units/:unit_id/communication_sets/:communication_set_id/rules' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])

    present communication_set.communication_rules.includes(:communication_conditions, :communication_actions),
            with: Entities::CommunicationRuleEntity
  end

  desc 'Create a communication rule for a communication set'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
    requires :communication_rule, type: Hash do
      requires :name, type: String
      requires :operator, type: String
      optional :position, type: Integer
      optional :active, type: Boolean
      optional :send_log_to_convenors, type: Boolean
    end
  end
  post '/units/:unit_id/communication_sets/:communication_set_id/rules' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])
    rule_params = ActionController::Parameters.new(params)
                                              .require(:communication_rule)
                                              .permit(:name, :operator, :position, :active, :send_log_to_convenors)

    rule_params[:position] = communication_set.communication_rules.count if rule_params[:position].nil?
    rule = communication_set.communication_rules.create!(rule_params)
    present rule, with: Entities::CommunicationRuleEntity
  end

  desc 'Update a communication rule'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
    requires :communication_rule, type: Hash do
      optional :name, type: String
      optional :operator, type: String
      optional :position, type: Integer
      optional :active, type: Boolean
      optional :send_log_to_convenors, type: Boolean
    end
  end
  put '/units/:unit_id/communication_rules/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:id])
    rule_params = ActionController::Parameters.new(params)
                                              .require(:communication_rule)
                                              .permit(:name, :operator, :position, :active, :send_log_to_convenors)

    rule.update!(rule_params)
    present rule, with: Entities::CommunicationRuleEntity
  end

  desc 'Execute a communication rule within its communication set'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  post '/units/:unit_id/communication_rules/:id/execute' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to execute unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:id])
    job_id = ExecuteCommunicationSetJob.perform_async(rule.communication_set_id, rule.id)
    job = setup_job(job_id)

    present job, with: Entities::SidekiqJobEntity
  end

  desc 'Preview projects matched by a communication rule'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  post '/units/:unit_id/communication_rules/:id/preview' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_students
      error!({ error: 'Not authorised to preview unit communications' }, 403)
    end

    # rule = unit.communication_rules.find(params[:id])
    # job_id = CommunicationRuleJob.perform_async(rule.id)
    # job = setup_job(job_id)

    # present job, with: Entities::SidekiqJobEntity
    # rule = unit.communication_rules.find(params[:id])

    rule = unit.communication_rules.find(params[:id])
    allocations = rule.communication_set.preview_allocations_for_rule(rule)

    present(
      target_rule_id: rule.id,
      allocations: allocations.map do |allocation|
        {
          rule_id: allocation[:rule].id,
          rule_name: allocation[:rule].name,
          position: allocation[:rule].position,
          students: allocation[:projects].map do |project|
            {
              first_name: project.user&.first_name,
              last_name: project.user&.last_name,
              preferred_name: project.user&.nickname,
              username: project.user&.username,
              student_id: project.user&.student_id,
              full_name: [project.user&.first_name, project.user&.last_name].compact.join(' '),
              target_grade: project.target_grade,
              last_sign_in_at: project.user&.last_sign_in_at,
              campus: project.campus&.name
            }
          end
        }
      end
    )
  end

  desc 'Get communication conditions for a rule'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
  end
  get '/units/:unit_id/communication_rules/:communication_rule_id/conditions' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])

    present rule.communication_conditions, with: Entities::CommunicationConditionEntity
  end

  desc 'Delete a communication rule'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  delete '/units/:unit_id/communication_rules/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:id])
    rule.destroy!
    status 204
  end

  desc 'Create a communication condition'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
    requires :communication_condition, type: Hash do
      requires :type, type: String
      requires :operator, type: String
      optional :target_grade, type: Integer
      optional :task_definition_id, type: Integer
      optional :task_statuses, type: Array[String]
      optional :task_status_count, type: Integer
      optional :task_target_grade, type: Integer
      optional :last_sign_in_at, type: DateTime
      optional :tutorial_id, type: Integer
      optional :tutorial_stream_id, type: Integer
      optional :campus_id, type: Integer
    end
  end
  post '/units/:unit_id/communication_rules/:communication_rule_id/conditions' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    raw_condition_params = params[:communication_condition]
    condition_params = {
      type: raw_condition_params[:type],
      operator: raw_condition_params[:operator],
      target_grade: raw_condition_params[:target_grade],
      task_definition_id: raw_condition_params[:task_definition_id],
      task_status_count: raw_condition_params[:task_status_count],
      task_target_grade: raw_condition_params[:task_target_grade],
      last_sign_in_at: raw_condition_params[:last_sign_in_at],
      tutorial_id: raw_condition_params[:tutorial_id],
      tutorial_stream_id: raw_condition_params[:tutorial_stream_id],
      campus_id: raw_condition_params[:campus_id]
    }.compact

    task_statuses = raw_condition_params[:task_statuses]
    condition_params[:task_statuses] = Array(task_statuses) unless task_statuses.nil?

    condition = rule.communication_conditions.create!(condition_params)
    present condition, with: Entities::CommunicationConditionEntity
  end

  desc 'Update a communication condition'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
    requires :id, type: Integer
    requires :communication_condition, type: Hash do
      optional :type, type: String
      optional :operator, type: String
      optional :target_grade, type: Integer
      optional :task_definition_id, type: Integer
      optional :task_statuses, type: Array[String]
      optional :task_status_count, type: Integer
      optional :task_target_grade, type: Integer
      optional :last_sign_in_at, type: DateTime
      optional :tutorial_id, type: Integer
      optional :tutorial_stream_id, type: Integer
      optional :campus_id, type: Integer
    end
  end
  put '/units/:unit_id/communication_rules/:communication_rule_id/conditions/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    condition = rule.communication_conditions.find(params[:id])
    raw_condition_params = params[:communication_condition]
    condition_params = {
      type: raw_condition_params[:type],
      operator: raw_condition_params[:operator],
      target_grade: raw_condition_params[:target_grade],
      task_definition_id: raw_condition_params[:task_definition_id],
      task_status_count: raw_condition_params[:task_status_count],
      task_target_grade: raw_condition_params[:task_target_grade],
      last_sign_in_at: raw_condition_params[:last_sign_in_at],
      tutorial_id: raw_condition_params[:tutorial_id],
      tutorial_stream_id: raw_condition_params[:tutorial_stream_id],
      campus_id: raw_condition_params[:campus_id]
    }.compact

    task_statuses = raw_condition_params[:task_statuses]
    condition_params[:task_statuses] = Array(task_statuses) unless task_statuses.nil?

    condition.update!(condition_params)
    present condition, with: Entities::CommunicationConditionEntity
  end

  desc 'Get communication actions for a rule'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
  end
  get '/units/:unit_id/communication_rules/:communication_rule_id/actions' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])

    present rule.communication_actions, with: Entities::CommunicationActionEntity
  end

  desc 'Delete a communication condition'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
    requires :id, type: Integer
  end
  delete '/units/:unit_id/communication_rules/:communication_rule_id/conditions/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    rule.communication_conditions.find(params[:id]).destroy!
    status 204
  end

  desc 'Create a communication action'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
    requires :communication_action, type: Hash do
      requires :type, type: String
      optional :subject, type: String
      optional :body, type: String
      optional :email_tutors, type: Boolean
      optional :email_convenors, type: Boolean
      optional :target_grade, type: Integer
    end
  end
  post '/units/:unit_id/communication_rules/:communication_rule_id/actions' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    action_params = ActionController::Parameters.new(params)
                                                .require(:communication_action)
                                                .permit(
                                                  :type,
                                                  :subject,
                                                  :body,
                                                  :email_tutors,
                                                  :email_convenors,
                                                  :target_grade
                                                )

    action = rule.communication_actions.create!(action_params)
    present action, with: Entities::CommunicationActionEntity
  end

  desc 'Update a communication action'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
    requires :id, type: Integer
    requires :communication_action, type: Hash do
      optional :type, type: String
      optional :subject, type: String
      optional :body, type: String
      optional :email_tutors, type: Boolean
      optional :email_convenors, type: Boolean
      optional :target_grade, type: Integer
    end
  end
  put '/units/:unit_id/communication_rules/:communication_rule_id/actions/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    action = rule.communication_actions.find(params[:id])
    action_params = ActionController::Parameters.new(params)
                                                .require(:communication_action)
                                                .permit(:type, :subject, :body, :email_tutors, :email_convenors, :target_grade)

    action.update!(action_params)
    present action, with: Entities::CommunicationActionEntity
  end

  desc 'Delete a communication action'
  params do
    requires :unit_id, type: Integer
    requires :communication_rule_id, type: Integer
    requires :id, type: Integer
  end
  delete '/units/:unit_id/communication_rules/:communication_rule_id/actions/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    rule.communication_actions.find(params[:id]).destroy!
    status 204
  end
end
