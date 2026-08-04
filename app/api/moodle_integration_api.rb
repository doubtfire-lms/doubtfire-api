# frozen_string_literal: true

require 'grape'
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

    integration = unit.moodle_integration
    present(
      {
        id: integration&.id,
        course_id: integration&.course_id,
        assignment_id: integration&.assignment_id,
        assignment_name: integration&.assignment_name,
        fetch_extensions: integration&.fetch_extensions || false,
        api_key_configured: integration&.api_key.present?
      },
      with: Grape::Presenters::Presenter
    )
  end

  desc 'Update Moodle settings for a unit'
  params do
    requires :course_id, type: Integer
    optional :api_key, type: String
    optional :assignment_id, type: Integer
    optional :assignment_name, type: String
    optional :fetch_extensions, type: Boolean, default: false
  end
  put '/units/:unit_id/moodle' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Moodle integration is not enabled for this unit' }, 404) unless unit.moodle_enabled?
    unless authorise?(current_user, unit, :update)
      error!({ error: 'Not authorised to manage Moodle for this unit' }, 403)
    end

    integration = unit.moodle_integration || unit.build_moodle_integration
    integration.course_id = params[:course_id]
    integration.api_key = params[:api_key] if params[:api_key].present?
    integration.fetch_extensions = params[:fetch_extensions]
    integration.assignment_id = params[:fetch_extensions] ? params[:assignment_id] : nil
    integration.assignment_name = params[:fetch_extensions] ? params[:assignment_name] : nil
    integration.save!

    present(
      {
        id: integration.id,
        course_id: integration.course_id,
        assignment_id: integration.assignment_id,
        assignment_name: integration.assignment_name,
        fetch_extensions: integration.fetch_extensions,
        api_key_configured: integration.api_key.present?
      },
      with: Grape::Presenters::Presenter
    )
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
