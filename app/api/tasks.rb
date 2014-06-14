require 'grape'
require 'task_serializer'

module Api
  class Tasks < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    # desc "Get all the current user's tasks"
    # get '/tasks' do
    #   tasks = Task.for_user current_user
    # end

    # desc "Get task"
    # get '/tasks/:id' do
    #   task = Task.find(params[:id])
    #   #TODO: auth!

    #   if authorise? current_user, task, :get
    #     task
    #   else
    #     error!({"error" => "Couldn't find Task with id=#{params[:id]}" }, 403)
    #   end
    # end

    desc "Update a task"
    params do
      requires :id, type: Integer, desc: 'The task id to update'
      requires :trigger, type: String, desc: 'New status'
    end
    put '/tasks/:id' do
      task = Task.find(params[:id])

      if authorise? current_user, task, :get
        task.trigger_transition( params[:trigger], current_user )
        TaskUpdateSerializer.new(task)
      else
        error!({"error" => "Couldn't find Task with id=#{params[:id]}" }, 403)
      end 
    end
  end
end


