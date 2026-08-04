# frozen_string_literal: true

require 'grape'
require 'entities/moodle_integration_entity'
require 'entities/sidekiq_job_entity'

class MoodleIntegrationApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers SidekiqHelper

  before do
    authenticated?
  end

  desc 'Get Moodle settings for a unit'
  get '/units/:unit_id/moodle' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Moodle integration is not enabled for this unit' }, 404) unless unit.moodle_enabled?
    unless authorise?(current_user, unit, :update)
      error!({ error: 'Not authorised to manage Moodle for this unit' }, 403)
    end

    integration = unit.moodle_integration || unit.build_moodle_integration
    present integration, with: Entities::MoodleIntegrationEntity
  end

  desc 'Update Moodle settings for a unit'
  params do
    requires :course_id, type: Integer
    optional :api_key, type: String
    optional :assignment_id, type: Integer
    optional :assignment_name, type: String
    optional :fetch_extensions, type: Boolean, default: false
    optional :group_mapping_enabled, type: Boolean, default: false
    optional :group_mappings, type: Array do
      requires :moodle_group_id, type: Integer
      requires :moodle_group_name, type: String
      requires :target_type, type: String, values: MoodleGroupMapping::TARGET_TYPES
      optional :group_set_id, type: Integer
      optional :group_id, type: Integer
      optional :campus_id, type: Integer
      optional :tutorial_stream_id, type: Integer
      optional :tutorial_id, type: Integer
      optional :create_if_missing, type: Boolean, default: false
    end
  end
  put '/units/:unit_id/moodle' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Moodle integration is not enabled for this unit' }, 404) unless unit.moodle_enabled?
    unless authorise?(current_user, unit, :update)
      error!({ error: 'Not authorised to manage Moodle for this unit' }, 403)
    end

    integration = unit.moodle_integration || unit.build_moodle_integration
    MoodleIntegration.transaction do
      integration.course_id = params[:course_id]
      integration.api_key = params[:api_key] if params[:api_key].present?
      integration.fetch_extensions = params[:fetch_extensions]
      integration.assignment_id = params[:fetch_extensions] ? params[:assignment_id] : nil
      integration.assignment_name = params[:fetch_extensions] ? params[:assignment_name] : nil
      integration.group_mapping_enabled = params[:group_mapping_enabled]
      integration.save!

      if integration.group_mapping_enabled?
        integration.moodle_group_mappings.delete_all
        Array(params[:group_mappings]).each do |mapping|
          integration.moodle_group_mappings.create!(
            moodle_group_id: mapping[:moodle_group_id],
            moodle_group_name: mapping[:moodle_group_name],
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

    integration.moodle_group_mappings.reload
    present integration, with: Entities::MoodleIntegrationEntity
  end

  desc 'Test Moodle API permissions for a unit'
  post '/units/:unit_id/moodle/test' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Moodle integration is not enabled for this unit' }, 404) unless unit.moodle_enabled?
    unless authorise?(current_user, unit, :update)
      error!({ error: 'Not authorised to manage Moodle for this unit' }, 403)
    end
    error!({ error: 'Configure Moodle for this unit first' }, 422) if unit.moodle_integration.blank?

    job_id = TestMoodleConnectionJob.perform_async(unit.id)
    job = setup_job(job_id)
    present job, with: Entities::SidekiqJobEntity
  end

  desc 'Import active Moodle students into a unit'
  params do
    requires :preview_only, type: Boolean, default: false
  end
  post '/units/:unit_id/moodle/import_students' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Moodle integration is not enabled for this unit' }, 404) unless unit.moodle_enabled?
    unless authorise?(current_user, unit, :upload_csv)
      error!({ error: 'Not authorised to manage Moodle for this unit' }, 403)
    end
    error!({ error: 'Configure Moodle for this unit first' }, 422) if unit.moodle_integration.blank?

    job_id = ImportMoodleStudentsJob.perform_async(unit.id, params[:preview_only])
    present setup_job(job_id), with: Entities::SidekiqJobEntity
  end

  desc 'Import Moodle assignment extensions into a unit'
  params do
    requires :preview_only, type: Boolean, default: false
  end
  post '/units/:unit_id/moodle/import_extensions' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Moodle integration is not enabled for this unit' }, 404) unless unit.moodle_enabled?
    unless authorise?(current_user, unit, :update)
      error!({ error: 'Not authorised to manage Moodle for this unit' }, 403)
    end

    integration = unit.moodle_integration
    error!({ error: 'Configure Moodle for this unit first' }, 422) if integration.blank?
    unless integration.fetch_extensions && integration.assignment_id.present?
      error!({ error: 'Enable extension imports and select a Moodle assignment first' }, 422)
    end

    job_id = ImportMoodleExtensionsJob.perform_async(unit.id, params[:preview_only])
    present setup_job(job_id), with: Entities::SidekiqJobEntity
  end
end
