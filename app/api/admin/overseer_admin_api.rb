require 'grape'

module Admin
  class OverseerAdminApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers SidekiqHelper

    before do
      authenticated?
    end

    desc 'Add an overseer image'
    params do
      requires :overseer_image, type: Hash do
        requires :name, type: String,  desc: 'The name to display for this image'
        requires :tag,  type: String,  desc: 'The tag used to receive from container repo'
      end
    end
    post '/admin/overseer_images' do
      unless authorise? current_user, User, :admin_overseer
        error!({ error: 'Not authorised to create overseer images' }, 403)
      end
      unless Doubtfire::Application.config.overseer_enabled
        error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
      end
      overseer_image_params = ActionController::Parameters.new(params)
                                                          .require(:overseer_image)
                                                          .permit(:name,
                                                                  :tag)

      result = OverseerImage.create!(overseer_image_params)

      if result.nil?
        error!({ error: 'No overseer image added' }, 403)
      else
        present result, with: Entities::OverseerImageEntity
      end
    end

    desc 'Update an overseer image'
    params do
      requires :overseer_image, type: Hash do
        optional :name, type: String,  desc: 'The name of the overseer image'
        optional :tag,  type: String,  desc: 'The tag used to receive from container repo'
      end
    end
    put '/admin/overseer_images/:id' do
      unless authorise? current_user, User, :admin_overseer
        error!({ error: 'Not authorised to update an overseer image' }, 403)
      end
      unless Doubtfire::Application.config.overseer_enabled
        error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
      end

      overseer_image = OverseerImage.find(params[:id])

      overseer_image_params = ActionController::Parameters.new(params)
                                                          .require(:overseer_image)
                                                          .permit(:name,
                                                                  :tag)

      # Clear image status and text when updating
      overseer_image_params[:pulled_image_status] = nil
      overseer_image_params[:pulled_image_text] = nil
      overseer_image_params[:last_pulled_date] = nil

      overseer_image.update!(overseer_image_params)
      present overseer_image, with: Entities::OverseerImageEntity
    end

    desc 'Delete an overseer image'
    delete '/admin/overseer_images/:id' do
      unless authorise? current_user, User, :admin_overseer
        error!({ error: 'Not authorised to delete an overseer image' }, 403)
      end

      overseer_image = OverseerImage.find(params[:id])
      overseer_image.destroy
      error!({ error: overseer_image.errors.full_messages.last }, 403) unless overseer_image.destroyed?

      present overseer_image.destroyed?, with: Grape::Presenters::Presenter
    end

    desc 'Get all overseer images'
    get '/admin/overseer_images' do
      unless authorise? current_user, User, :use_overseer
        error!({ error: 'Not authorised to get overseer images' }, 403)
      end

      if Doubtfire::Application.config.overseer_enabled
        present OverseerImage.all, with: Entities::OverseerImageEntity
      else
        present [], with: Grape::Presenters::Presenter
      end
    end

    desc 'Get all overseer images'
    get '/admin/overseer_images/:id' do
      unless authorise? current_user, User, :use_overseer
        error!({ error: 'Not authorised to get overseer images' }, 403)
      end

      if Doubtfire::Application.config.overseer_enabled
        present OverseerImage.find(params[:id]), with: Entities::OverseerImageEntity
      else
        present [], with: Grape::Presenters::Presenter
      end
    end

    desc 'Get overseer image by id and pull image'
    put '/admin/overseer_images/:id/pull_image' do
      unless authorise? current_user, User, :admin_overseer
        error!({ error: 'Not authorised to pull an overseer image' }, 403)
      end
      unless Doubtfire::Application.config.overseer_enabled
        error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
      end

      overseer_image = OverseerImage.find(params[:id])

      job_id = PullDockerImageJob.perform_async(overseer_image.id)
      job = setup_job(job_id)

      present job, with: Entities::SidekiqJobEntity
    end

    desc 'Get available space'
    get '/admin/disk_space' do
      unless authorise? current_user, User, :use_overseer
        error!({ error: 'Not authorised to get disk space' }, 403)
      end

      unless Doubtfire::Application.config.disk_space_endpoint_enabled
        error!({ error: 'Not authorised to get disk space' }, 403)
      end

      stat = Sys::Filesystem.stat("/")
      free_bytes = stat.block_size * stat.blocks_available
      free_gb = free_bytes.to_f / 1024 / 1024 / 1024

      present free_gb.round(2), with: Grape::Presenters::Presenter
    rescue Sys::Filesystem::Error => e
      error!({ error: "Filesystem stat failed", detail: e.message }, 500)
    end

    desc 'Get basic institution statistics'
    get '/admin/statistics' do
      unless authorise? current_user, User, :admin_overseer
        error!({ error: 'Not authorised to view institution statistics' }, 403)
      end

      now = Time.current
      activity_windows = {
        fiveMinutes: 5.minutes,
        fifteenMinutes: 15.minutes,
        thirtyMinutes: 30.minutes,
        oneHour: 1.hour,
        twentyFourHours: 24.hours,
        sevenDays: 7.days
      }

      active_users = activity_windows.transform_values do |duration|
        User.where(last_access_at: (now - duration)..).count
      end

      disk_space_gb = nil
      if Doubtfire::Application.config.disk_space_endpoint_enabled
        stat = Sys::Filesystem.stat('/')
        disk_space_gb = (stat.block_size * stat.blocks_available).to_f / 1024 / 1024 / 1024
      end

      present({
                activeUsers: active_users,
                totalUsers: User.count,
                diskSpaceGb: disk_space_gb&.round(2)
              }, with: Grape::Presenters::Presenter)
    rescue Sys::Filesystem::Error
      present({
                activeUsers: active_users,
                totalUsers: User.count,
                diskSpaceGb: nil
              }, with: Grape::Presenters::Presenter)
    end
  end
end
