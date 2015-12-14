require 'grape'
require 'task_serializer'

module Api
  class Tasks < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get all the current user's tasks"
    params do
      requires :unit_id, type: Integer, desc: 'Unit to fetch the task details for'
    end
    get '/tasks' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :get_students
        error!({"error" => "You do not have permission to read these task details"}, 403)
      end

      unit.student_tasks.
        joins(project: :unit_role).
        joins(:task_status).
        select('tasks.id', 'unit_roles.tutorial_id as tutorial_id', 'task_statuses.name as status_name', 'task_definition_id').
        where("tasks.task_status_id > 1 and unit_roles.tutorial_id is not null").
        map { |r|  
          {
            id: r.id,
            tutorial_id: r.tutorial_id,
            task_definition_id: r.task_definition_id,
            status: TaskStatus.status_key_for_name(r.status_name)
          }
        }
    end

    desc "Get a similarity match for a given task"
    get '/tasks/:id/similarity/:count' do
      if not authenticated?
        error!({"error" => "Not authorised to download details for task '#{params[:id]}'"}, 401)
      end
      task = Task.find(params[:id])

      if not authorise? current_user, task, :get_submission
        error!({"error" => "Not authorised to download details for task '#{params[:id]}'"}, 401)
      end

      match = params[:count].to_i % task.similar_to_count
      if match < 0
        error!({"error" => "Invalid match sequence, must be 0 or larger"}, 403)
      end

      match_link = task.plagiarism_match_links.order("created_at DESC")[match]
      return if match_link.nil?

      # puts "here 1: #{match_link}"
      
      other_match_link = match_link.other_party

      # puts "here 2: #{other_match_link}"

      output = FileHelper.path_to_plagarism_html(match_link)

      if output.nil? || ! File.exists?(output)
        error!({"error" => "No files to download"}, 403)
      end

      # check if returning both parties
      if not authorise? current_user, other_match_link.task, :get_submission
        {
          student: {
            username: match_link.student.username,
            name: match_link.student.name,
            tutor: match_link.tutor.name,
            tutorial: match_link.tutorial,
            html: File.read(output),
            lnk: (match_link.plagiarism_report_url if authorise? current_user, match_link.task, :view_plagiarism ),
            pct: match_link.pct
          },
          other_student: {
            username: "???",
            name: "???",
            tutor: match_link.other_tutor.name,
            tutorial: match_link.other_tutorial,
            html: "<pre>???</pre>",
            lnk: "",
            pct: other_match_link.pct
          }
        }
      else
        otherOutput = FileHelper.path_to_plagarism_html(other_match_link)

        {
          student: {
            username: match_link.student.username,
            name: match_link.student.name,
            tutor: match_link.tutor.name,
            tutorial: match_link.tutorial,
            html: File.read(output),
            lnk: (match_link.plagiarism_report_url if authorise? current_user, match_link.task, :view_plagiarism ),
            pct: match_link.pct
          },
          other_student: {
            username: match_link.other_student.username,
            name: match_link.other_student.name,
            tutor: match_link.other_tutor.name,
            tutorial: match_link.other_tutorial,
            html: File.read(otherOutput),
            lnk: (other_match_link.plagiarism_report_url if authorise? current_user, other_match_link.task, :view_plagiarism),
            pct: other_match_link.pct
          }
        }
      end
    end

    # desc "Get task"
    # get '/tasks/:id' do
    #   task = Task.find(params[:id])

    #   if authorise? current_user, task, :get
    #     task
    #   else
    #     error!({"error" => "Couldn't find Task with id=#{params[:id]}" }, 403)
    #   end
    # end

    desc "Update a task"
    params do
      requires :id, type: Integer, desc: 'The task id to update'
      optional :trigger, type: String, desc: 'New status'
      optional :include_in_portfolio, type: Boolean, desc: 'Include or exclude from portfolio'
    end
    put '/tasks/:id' do
      task = Task.find(params[:id])
      needsUploadDocs = task.upload_requirements.length > 0
      
      # check the user can put this task
      if authorise? current_user, task, :put
        # if trigger supplied...
        unless params[:trigger].nil?
          # Check if they should be using portfolio_evidence api
          if needsUploadDocs && params[:trigger] == 'ready_to_mark'
            error!({"error" => "Cannot set this task status to ready to mark without uploading documents." }, 403)
          end
          result = task.trigger_transition( params[:trigger], current_user )
          if result.nil? && task.task_definition.restrict_status_updates
            error!({"error" => "This task can only be updated by your tutor." }, 403)
          end
        end
        # if include in portfolio supplied
        unless params[:include_in_portfolio].nil?
          task.include_in_portfolio = params[:include_in_portfolio]
          task.save
        end

        TaskUpdateSerializer.new(task)
      else
        error!({"error" => "Couldn't find Task with id=#{params[:id]}" }, 403)
      end 
    end
    
  end
end


