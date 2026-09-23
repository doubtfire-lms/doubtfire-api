# frozen_string_literal: true

require 'grape'
require 'entities/lms_integration_entity'
require 'entities/sidekiq_job_entity'

#
# The unit LMS tab. Links are created by launching OnTrack from the LMS; everything here reads
# the link and course data through the LTI service and manages how that data is imported.
#
class LmsIntegrationApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers SidekiqHelper

  before do
    authenticated?
  end

  helpers do
    def lms_unit!(permission = :update)
      error!({ error: 'LTI is not enabled for this OnTrack deployment' }, 404) unless Doubtfire::Application.config.lti_enabled

      unit = Unit.find(params[:unit_id])
      error!({ error: 'Not authorised to manage the LMS integration for this unit' }, 403) unless authorise?(current_user, unit, permission)
      unit
    end

    def lms_error!(error)
      status = error.respond_to?(:status) && error.status.to_i.between?(400, 599) ? error.status.to_i : 422
      error!({ error: error.message }, status)
    end

    def require_link!(unit)
      link = LtiServer.new(unit.id).link
      error!({ error: 'This unit is not linked to an LMS course. Link it by launching OnTrack from the LMS.' }, 409) if link.nil?
      link
    rescue LtiServer::Error => e
      lms_error!(e)
    end
  end

  desc 'Get the LMS link and integration settings for a unit'
  get '/units/:unit_id/lms' do
    unit = lms_unit!
    link = nil
    link_error = nil
    begin
      link = LtiServer.new(unit.id).link
    rescue LtiServer::Error => e
      link_error = e.message
    end

    integration = unit.lms_integration || unit.build_lms_integration
    {
      link: link,
      link_error: link_error,
      integration: Entities::LmsIntegrationEntity.represent(integration)
    }
  end

  desc 'Unlink the unit from its LMS course. It can only be linked again from an LMS launch.'
  delete '/units/:unit_id/lms/link' do
    unit = lms_unit!
    begin
      LtiServer.new(unit.id).unlink
    rescue LtiServer::Error => e
      lms_error!(e)
    end
    unit.lms_integration&.mark_unvalidated!
    logger.info "Unlinked unit #{unit.code} from its LMS course by #{current_user.username}"
    { unlinked: true }
  end

  desc 'Update LMS integration settings for a unit'
  params do
    optional :assignment_id, type: Integer
    optional :assignment_name, type: String
    optional :fetch_extensions, type: Boolean, default: false
    optional :auto_sync_students, type: Boolean, default: false
    optional :withdraw_missing_students, type: Boolean, default: false
    optional :auto_sync_extensions, type: Boolean, default: false
    optional :group_mapping_enabled, type: Boolean, default: false
    optional :group_mappings, type: Array do
      requires :lms_group_id, type: Integer
      requires :lms_group_name, type: String
      requires :target_type, type: String, values: LmsGroupMapping::TARGET_TYPES
      optional :group_set_id, type: Integer
      optional :group_id, type: Integer
      optional :campus_id, type: Integer
      optional :tutorial_stream_id, type: Integer
      optional :tutorial_id, type: Integer
      optional :create_if_missing, type: Boolean, default: false
    end
  end
  put '/units/:unit_id/lms' do
    unit = lms_unit!

    integration = unit.lms_integration || unit.build_lms_integration
    LmsIntegration.transaction do
      integration.fetch_extensions = params[:fetch_extensions]
      integration.assignment_id = params[:fetch_extensions] ? params[:assignment_id] : nil
      integration.assignment_name = params[:fetch_extensions] ? params[:assignment_name] : nil
      integration.auto_sync_students = params[:auto_sync_students]
      integration.withdraw_missing_students = params[:withdraw_missing_students]
      integration.auto_sync_extensions = params[:fetch_extensions] && params[:auto_sync_extensions]
      integration.group_mapping_enabled = params[:group_mapping_enabled]
      integration.validated = false
      integration.validated_at = nil
      integration.save!

      if integration.group_mapping_enabled?
        integration.lms_group_mappings.delete_all
        Array(params[:group_mappings]).each do |mapping|
          integration.lms_group_mappings.create!(
            lms_group_id: mapping[:lms_group_id],
            lms_group_name: mapping[:lms_group_name],
            target_type: mapping[:target_type],
            group_set_id: mapping[:group_set_id],
            group_id: mapping[:group_id],
            campus_id: mapping[:campus_id],
            tutorial_stream_id: mapping[:tutorial_stream_id],
            tutorial_id: mapping[:tutorial_id],
            create_if_missing: mapping[:create_if_missing]
          )
        end
      end
    end

    integration.lms_group_mappings.reload
    present integration, with: Entities::LmsIntegrationEntity
  end

  desc 'Update individual LMS integration settings without replacing the group mappings'
  params do
    optional :fetch_extensions, type: Boolean
    optional :auto_sync_students, type: Boolean
    optional :withdraw_missing_students, type: Boolean
    optional :auto_sync_extensions, type: Boolean
    optional :group_mapping_enabled, type: Boolean
    optional :skip_ungraded, type: Boolean
    optional :send_grade_rationale, type: Boolean
    optional :assignment_id, type: Integer
    optional :assignment_name, type: String
    all_or_none_of :assignment_id, :assignment_name
    at_least_one_of :fetch_extensions, :auto_sync_students, :withdraw_missing_students, :auto_sync_extensions, :group_mapping_enabled, :skip_ungraded, :send_grade_rationale, :assignment_id
  end
  patch '/units/:unit_id/lms/settings' do
    unit = lms_unit!

    integration = unit.lms_integration || unit.build_lms_integration
    changes = declared(params, include_missing: false).to_h.symbolize_keys.except(:unit_id)
    integration.assign_attributes(changes)
    integration.auto_sync_extensions = false unless integration.fetch_extensions?
    # Turning a feature on or changing the assignment adds something to check; turning one off does not
    turned_on = %i[fetch_extensions group_mapping_enabled].any? { |setting| integration.will_save_change_to_attribute?(setting, to: true) }
    if turned_on || integration.assignment_id_changed?
      integration.validated = false
      integration.validated_at = nil
    end
    integration.save!

    present integration, with: Entities::LmsIntegrationEntity
  end

  desc 'Get course details, groups and assignments from the LMS course-data plugin'
  get '/units/:unit_id/lms/course_data' do
    unit = lms_unit!
    require_link!(unit)

    source = LmsIntegration.data_source_for(unit)
    begin
      error!({ error: 'The Moodle OnTrack course-data plugin is not available for this course.' }, 422) unless source.course_data_available?

      {
        course: source.course,
        groups: source.groups,
        assignments: source.assignments
      }
    rescue LtiCourseDataSource::Error => e
      lms_error!(e)
    end
  end

  desc 'Validate LMS group mappings and the selected assignment against the LMS course'
  post '/units/:unit_id/lms/validate' do
    unit = lms_unit!
    integration = unit.lms_integration
    error!({ error: 'Save the LMS settings for this unit first' }, 422) if integration.blank?
    require_link!(unit)

    source = integration.data_source
    begin
      needs_course_data = integration.group_mapping_enabled? || integration.fetch_extensions?
      if needs_course_data && !source.course_data_available?
        error!({ error: 'Group mapping and extensions need the Moodle OnTrack course-data plugin.' }, 422)
      end

      LmsIntegrationValidator.new(integration).validate(
        groups: integration.group_mapping_enabled? ? source.groups : [],
        assignments: integration.fetch_extensions? ? source.assignments : []
      )
    rescue LtiCourseDataSource::Error => e
      lms_error!(e)
    end
  end

  desc 'Pre-fill LMS group mappings using institution settings'
  params do
    requires :groups, type: Array do
      requires :id, type: Integer
      requires :name, type: String
      optional :idnumber, type: String
    end
  end
  post '/units/:unit_id/lms/prefill_group_mappings' do
    unit = lms_unit!

    settings = Doubtfire::Application.config.institution_settings
    groups = params[:groups].map { |group| group.to_h.symbolize_keys }
    mappings = if settings.respond_to?(:prefill_lms_group_mappings)
                 settings.prefill_lms_group_mappings(unit, groups)
               else
                 groups.map do |group|
                   { lms_group_id: group[:id], lms_group_name: group[:name], target_type: 'ignore' }
                 end
               end
    { group_mappings: mappings }
  end

  desc 'Import LMS course members into a unit'
  params do
    requires :preview_only, type: Boolean, default: false
    optional :withdraw_missing, type: Boolean, desc: 'Withdraw enrolled students who are not active students in the LMS'
  end
  post '/units/:unit_id/lms/import_students' do
    unit = lms_unit!(:upload_csv)
    link = require_link!(unit)

    integration = unit.lms_integration
    # Without the course-data plugin there are no groups, so mappings are not applied
    if integration&.group_mapping_enabled? && !integration.validated? && link['courseDataAvailable'] == true
      error!({ error: 'Validate the LMS group mappings before importing students' }, 422)
    end

    withdraw_missing = params[:withdraw_missing].nil? ? integration&.withdraw_missing_students == true : params[:withdraw_missing]
    job_id = ImportLmsStudentsJob.perform_async(unit.id, params[:preview_only], withdraw_missing, false)
    present setup_job(job_id), with: Entities::SidekiqJobEntity
  end

  desc 'Import LMS assignment extensions into a unit'
  params do
    requires :preview_only, type: Boolean, default: false
  end
  post '/units/:unit_id/lms/import_extensions' do
    unit = lms_unit!
    require_link!(unit)

    integration = unit.lms_integration
    unless integration&.fetch_extensions? && integration.assignment_id.present?
      error!({ error: 'Enable extension imports and select an LMS assignment first' }, 422)
    end
    error!({ error: 'Validate the LMS integration before importing extensions' }, 422) unless integration.validated?

    job_id = ImportLmsExtensionsJob.perform_async(unit.id, params[:preview_only], false)
    present setup_job(job_id), with: Entities::SidekiqJobEntity
  end

  desc 'Get the LMS grade item linked to a unit'
  get '/units/:unit_id/lms/grade_line_item' do
    unit = lms_unit!
    begin
      LtiServer.new(unit.id).grade_line_item
    rescue LtiServer::Error => e
      lms_error!(e)
    end
  end

  desc 'Find or create the LMS grade item linked to a unit'
  post '/units/:unit_id/lms/grade_line_item' do
    unit = lms_unit!
    require_link!(unit)
    begin
      LtiServer.new(unit.id).ensure_grade_line_item
    rescue LtiServer::Error => e
      lms_error!(e)
    end
  end

  desc 'Send OnTrack grades to the LMS grade item'
  params do
    optional :preview_only, type: Boolean, default: false
  end
  post '/units/:unit_id/lms/sync_grades' do
    unit = lms_unit!
    require_link!(unit)

    # A preview only reads course members, so it does not need the grade item
    unless params[:preview_only]
      begin
        grade_line_item = LtiServer.new(unit.id).grade_line_item
        unless grade_line_item['configured'] == true
          message = grade_line_item['message'].presence || 'Grade sync is not configured for this LMS course.'
          error!({ error: message }, 422)
        end
      rescue LtiServer::Error => e
        lms_error!(e)
      end
    end

    job_id = SyncLmsGradesJob.perform_async(unit.id, params[:preview_only])
    present setup_job(job_id), with: Entities::SidekiqJobEntity
  end
end
