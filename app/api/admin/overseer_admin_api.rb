require 'grape'

module Admin
  class OverseerAdminApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

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

    desc 'Get overseer image by id and pull image'
    put '/admin/overseer_images/:id/pull_image' do
      unless authorise? current_user, User, :admin_overseer
        error!({ error: 'Not authorised to pull an overseer image' }, 403)
      end
      unless Doubtfire::Application.config.overseer_enabled
        error!({ error: 'Overseer is not enabled. Enable Overseer before updating settings.' }, 403)
      end

      overseer_image = OverseerImage.find(params[:id])
      overseer_image.pull_from_docker

      present overseer_image, with: Entities::OverseerImageEntity
    end
  end
end
