require 'grape'

module Api
  class Projects < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get projects"
    get :projects do
      @projects = Project.for_user current_user
    end

    desc "Get project"
    get '/projects/:id' do
      @project = Project.find(params[:id])
    end
  end
end
