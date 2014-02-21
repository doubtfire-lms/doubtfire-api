require 'grape'

module Api
  class Projects < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get projects"
    get '/projects' do
      @projects = Project.for_user current_user

      if params[:unit_role_id]
        @projects = @projects.where(unit_role_id: params[:unit_role_id])
      end

      @projects
    end

    desc "Get project"
    get '/projects/:id' do
      @project = Project.find(params[:id])
    end
  end
end
