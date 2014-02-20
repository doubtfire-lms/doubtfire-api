require 'grape'

module Api
  class Tasks < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get tasks"
    get '/tasks' do
      @tasks = Task.for_user current_user
    end

    desc "Get task"
    get '/task/:id' do
      @task = Task.find(params[:id])
    end
  end
end
