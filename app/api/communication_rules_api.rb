require 'grape'
require 'entities/communication_set_entity'
require 'entities/communication_rule_entity'
require 'entities/communication_condition_entity'
require 'entities/communication_action_entity'
require 'entities/communication_set_schedule_entity'
require 'entities/sidekiq_job_entity'

class CommunicationRulesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers SidekiqHelper
  helpers do
    def permitted_schedule_params(raw_schedule)
      ActionController::Parameters.new(raw_schedule).permit(
        :id,
        :name,
        :active,
        :anchor_week,
        :anchor_day,
        :hour,
        :minute,
        :timezone,
        :recurrence,
        :interval,
        :repeat_count,
        :until_at
      )
    end

    def permitted_condition_params(raw_condition)
      ActionController::Parameters.new(raw_condition).permit(
        :type,
        :operator,
        :target_grade,
        :task_definition_id,
        :task_status_count,
        :task_target_grade,
        :last_sign_in_at,
        :activity_days,
        :spec_con_days,
        :tutorial_id,
        :tutorial_stream_id,
        :campus_id,
        :submitted_portfolio,
        task_statuses: []
      ).to_h.compact
    end

    # `project_id` is what clients use to subtract students claimed by earlier rules.
    def preview_student_payload(project)
      user = project.user

      {
        project_id: project.id,
        first_name: user&.first_name,
        last_name: user&.last_name,
        preferred_name: user&.nickname,
        username: user&.username,
        student_id: user&.student_id,
        full_name: [user&.first_name, user&.last_name].compact.join(' '),
        target_grade: project.target_grade,
        spec_con_days: project.spec_con_days,
        has_portfolio: project.portfolio_exists?,
        last_sign_in_at: user&.last_sign_in_at,
        last_viewed_at: project.last_viewed_at,
        campus: project.campus&.name
      }
    end

    def schedule_params_from_request
      communication_set_params = params[:communication_set] || params['communication_set'] || {}
      communication_set_params[:schedules] || communication_set_params['schedules']
    end

    # Rules are applied in order and each one removes the students it matches
    # from the rules below it, so one rule that cannot be evaluated makes every
    # rule under it wrong too. The whole set is refused, not just that rule.
    def reject_unresolved!(communication_set)
      return if communication_set.executable?

      error!(
        {
          error: 'This communication set references records that do not exist in this unit',
          unresolved_rules: communication_set.unresolved_rules.map { |rule| { id: rule.id, name: rule.name } }
        },
        409
      )
    end

    def sync_set_schedules!(communication_set, raw_schedules)
      schedules = Array(raw_schedules).map { |schedule| permitted_schedule_params(schedule).to_h }

      keep_ids = schedules.filter_map { |schedule| schedule['id'] || schedule[:id] }

      communication_set.transaction do
        communication_set.communication_set_schedules.where.not(id: keep_ids).destroy_all

        schedules.each do |schedule_attrs|
          schedule_id = schedule_attrs.delete('id') || schedule_attrs.delete(:id)

          if schedule_id.present?
            communication_set.communication_set_schedules.find(schedule_id).update!(schedule_attrs)
          else
            communication_set.communication_set_schedules.create!(schedule_attrs)
          end
        end
      end
    end
  end

  before do
    authenticated?

    unit = Unit.find(params[:unit_id])
    unless authorise? current_user, unit, :mannage_communications
      error!({ error: 'Not authorised to manage unit communications' }, 403)
    end
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

    present unit.communication_sets.includes(:communication_set_schedules, communication_rules: [:communication_conditions, :communication_actions]),
            with: Entities::CommunicationSetEntity
  end

  desc 'Get a communication set for a unit'
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
                            .includes(:communication_set_schedules, communication_rules: [:communication_conditions, :communication_actions])
                            .find(params[:id])

    # Previews are loaded per rule -- running the whole set here times out on
    # large units.
    present(
      id: communication_set.id,
      unit_id: communication_set.unit_id,
      name: communication_set.name,
      active: communication_set.active,
      executable: communication_set.executable?,
      eligible_student_count: communication_set.eligible_project_count,
      schedules: Entities::CommunicationSetScheduleEntity.represent(communication_set.communication_set_schedules),
      rules: Entities::CommunicationRuleEntity.represent(communication_set.communication_rules)
    )
  end

  desc 'Create a communication set for a unit'
  params do
    requires :unit_id, type: Integer
    requires :communication_set, type: Hash do
      requires :name, type: String
      optional :active, type: Boolean
      optional :schedules, type: Array do
        optional :name, type: String
        optional :active, type: Boolean
        optional :anchor_week, type: Integer
        optional :anchor_day, type: String
        optional :hour, type: Integer
        optional :minute, type: Integer
        optional :timezone, type: String
        optional :recurrence, type: String
        optional :interval, type: Integer
        optional :repeat_count, type: Integer
        optional :until_at, type: DateTime
      end
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
    sync_set_schedules!(communication_set, schedule_params_from_request)
    communication_set.reload
    present communication_set, with: Entities::CommunicationSetEntity
  end

  desc 'Update a communication set'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
    requires :communication_set, type: Hash do
      optional :name, type: String
      optional :active, type: Boolean
      optional :schedules, type: Array do
        optional :id, type: Integer
        optional :name, type: String
        optional :active, type: Boolean
        optional :anchor_week, type: Integer
        optional :anchor_day, type: String
        optional :hour, type: Integer
        optional :minute, type: Integer
        optional :timezone, type: String
        optional :recurrence, type: String
        optional :interval, type: Integer
        optional :repeat_count, type: Integer
        optional :until_at, type: DateTime
      end
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
    sync_set_schedules!(communication_set, schedule_params_from_request) if schedule_params_from_request.present? || (params[:communication_set] || params['communication_set'] || {}).key?(:schedules) || (params[:communication_set] || params['communication_set'] || {}).key?('schedules')
    communication_set.reload
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
    reject_unresolved!(communication_set)
    job_id = ExecuteCommunicationSetJob.perform_async(communication_set.id)
    job = setup_job(job_id)

    present job, with: Entities::SidekiqJobEntity
  end

  desc 'Get schedules for a communication set'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
  end
  get '/units/:unit_id/communication_sets/:communication_set_id/schedules' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get communication schedules' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])
    present communication_set.communication_set_schedules.order(:id),
            with: Entities::CommunicationSetScheduleEntity
  end

  desc 'Get a communication schedule'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
    requires :id, type: Integer
  end
  get '/units/:unit_id/communication_sets/:communication_set_id/schedules/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get communication schedules' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])
    schedule = communication_set.communication_set_schedules.find(params[:id])
    present schedule, with: Entities::CommunicationSetScheduleEntity
  end

  desc 'Create a communication schedule'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
    requires :communication_set_schedule, type: Hash do
      requires :name, type: String
      optional :active, type: Boolean
      requires :anchor_week, type: Integer
      requires :anchor_day, type: String
      optional :hour, type: Integer
      optional :minute, type: Integer
      optional :timezone, type: String
      optional :recurrence, type: String
      optional :interval, type: Integer
      optional :repeat_count, type: Integer
      optional :until_at, type: DateTime
    end
  end
  post '/units/:unit_id/communication_sets/:communication_set_id/schedules' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update communication schedules' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])
    schedule_params = permitted_schedule_params(params[:communication_set_schedule]).to_h
    schedule = communication_set.communication_set_schedules.create!(schedule_params)
    schedule.reload
    present schedule, with: Entities::CommunicationSetScheduleEntity
  end

  desc 'Update a communication schedule'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
    requires :id, type: Integer
    requires :communication_set_schedule, type: Hash do
      optional :name, type: String
      optional :active, type: Boolean
      optional :anchor_week, type: Integer
      optional :anchor_day, type: String
      optional :hour, type: Integer
      optional :minute, type: Integer
      optional :timezone, type: String
      optional :recurrence, type: String
      optional :interval, type: Integer
      optional :repeat_count, type: Integer
      optional :until_at, type: DateTime
    end
  end
  put '/units/:unit_id/communication_sets/:communication_set_id/schedules/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update communication schedules' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])
    schedule = communication_set.communication_set_schedules.find(params[:id])
    schedule_params = permitted_schedule_params(params[:communication_set_schedule]).to_h
    schedule.update!(schedule_params)
    schedule.reload
    present schedule, with: Entities::CommunicationSetScheduleEntity
  end

  desc 'Delete a communication schedule'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
    requires :id, type: Integer
  end
  delete '/units/:unit_id/communication_sets/:communication_set_id/schedules/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update communication schedules' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])
    communication_set.communication_set_schedules.find(params[:id]).destroy!
    status 204
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
    reject_unresolved!(rule.communication_set)
    job_id = ExecuteCommunicationSetJob.perform_async(rule.communication_set_id, rule.id)
    job = setup_job(job_id)

    present job, with: Entities::SidekiqJobEntity
  end

  # Callers reproduce the set's "first matching rule claims the student"
  # behaviour by subtracting the students returned for earlier rules.
  desc 'Preview projects matched by a communication rule, evaluated in isolation'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  get '/units/:unit_id/communication_rules/:id/preview' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_students
      error!({ error: 'Not authorised to preview unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:id])
    communication_set = rule.communication_set
    matched_projects = communication_set.independent_matches_for_rule(rule)

    present(
      rule_id: rule.id,
      rule_name: rule.name,
      position: rule.position,
      eligible_student_count: communication_set.eligible_projects.length,
      evaluated_at: Time.current,
      students: matched_projects.map { |project| preview_student_payload(project) }
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
      optional :activity_days, type: Integer
      optional :spec_con_days, type: Integer
      optional :tutorial_id, type: Integer
      optional :tutorial_stream_id, type: Integer
      optional :campus_id, type: Integer
      optional :submitted_portfolio, type: Boolean
    end
  end
  post '/units/:unit_id/communication_rules/:communication_rule_id/conditions' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    condition = rule.communication_conditions.create!(permitted_condition_params(params[:communication_condition]))
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
      optional :activity_days, type: Integer
      optional :spec_con_days, type: Integer
      optional :tutorial_id, type: Integer
      optional :tutorial_stream_id, type: Integer
      optional :campus_id, type: Integer
      optional :submitted_portfolio, type: Boolean
    end
  end
  put '/units/:unit_id/communication_rules/:communication_rule_id/conditions/:id' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    rule = unit.communication_rules.find(params[:communication_rule_id])
    condition = rule.communication_conditions.find(params[:id])
    condition.update!(permitted_condition_params(params[:communication_condition]))
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
      optional :task_definition_id, type: Integer
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
                                                  :target_grade,
                                                  :task_definition_id
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
      optional :task_definition_id, type: Integer
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
                                                .permit(:type, :subject, :body, :email_tutors, :email_convenors, :target_grade, :task_definition_id)

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

  desc 'Copy a communication set as a portable document'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  get '/units/:unit_id/communication_sets/:id/export' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    present CommunicationTransfer.export_set(unit.communication_sets.find(params[:id]))
  end

  desc 'Copy a communication rule as a portable document'
  params do
    requires :unit_id, type: Integer
    requires :id, type: Integer
  end
  get '/units/:unit_id/communication_rules/:id/export' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to get unit communications' }, 403)
    end

    present CommunicationTransfer.export_rule(unit.communication_rules.find(params[:id]))
  end

  desc 'Import a communication set from a copied document'
  params do
    requires :unit_id, type: Integer
    requires :document, type: Hash
  end
  post '/units/:unit_id/communication_sets/import' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    begin
      communication_set = CommunicationTransfer.import_set(params[:document], unit)
    rescue CommunicationTransfer::InvalidDocument => e
      error!({ error: e.message }, 400)
    end

    present communication_set, with: Entities::CommunicationSetEntity
  end

  desc 'Import a communication rule into an existing set'
  params do
    requires :unit_id, type: Integer
    requires :communication_set_id, type: Integer
    requires :document, type: Hash
  end
  post '/units/:unit_id/communication_sets/:communication_set_id/rules/import' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'Not authorised to update unit communications' }, 403)
    end

    communication_set = unit.communication_sets.find(params[:communication_set_id])

    begin
      rule = CommunicationTransfer.import_rule(params[:document], communication_set)
    rescue CommunicationTransfer::InvalidDocument => e
      error!({ error: e.message }, 400)
    end

    present rule, with: Entities::CommunicationRuleEntity
  end
end
