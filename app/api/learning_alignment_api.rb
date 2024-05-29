require 'grape'

class LearningAlignmentApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers

  before do
    authenticated?
  end

  desc 'Get the task/outcome alignment details for a unit or a project'
  params do
    requires :unit_id, type: Integer, desc: 'The id of the unit'
    optional :project_id, type: Integer, desc: 'The id of the student project to get the alignment from'
  end
  get '/units/:unit_id/learning_alignments' do
    unit = Unit.find(params[:unit_id])

    unless authorise?(current_user, unit, :get_unit)
      error!({ error: 'You are not authorised to access this unit.' }, 403)
    end

    if params[:project_id].nil?
      present unit.task_outcome_alignments, with: Entities::TaskOutcomeAlignmentEntity
    else
      proj = unit.projects.find(params[:project_id])
      unless authorise?(current_user, proj, :get)
        error!({ error: 'You are not authorised to access this project.' }, 403)
      end
      present proj.task_outcome_alignments, with: Entities::TaskOutcomeAlignmentEntity
    end
  end

  desc 'Download CSV of task alignments in this unit'
  params do
    requires :unit_id, type: Integer, desc: 'The id of the unit'
    optional :project_id, type: Integer, desc: 'The id of the student project to get the alignment from'
  end
  get '/units/:unit_id/learning_alignments/csv' do
    unit = Unit.find(params[:unit_id])

    unless authorise?(current_user, unit, :get_unit)
      error!({ error: 'You are not authorised to access this unit.' }, 403)
    end

    if params[:project_id].nil?
      unless authorise? current_user, unit, :download_unit_csv
        error!({ error: "Not authorised to download CSV of task alignment in #{unit.code}" }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Alignment.csv"
      header['Access-Control-Expose-Headers'] = 'Content-Disposition'
      env['api.format'] = :binary
      unit.export_task_alignment_to_csv
    else
      proj = unit.projects.find(params[:project_id])
      unless authorise?(current_user, proj, :get)
        error!({ error: 'You are not authorised to access this project.' }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-#{proj.student.name}-Task-Alignment.csv"
      header['Access-Control-Expose-Headers'] = 'Content-Disposition'
      env['api.format'] = :binary

      proj.export_task_alignment_to_csv
    end
  end

  desc 'Upload CSV of task to outcome alignments'
  params do
    requires :file, type: File, desc: 'CSV upload file.'
    optional :project_id, type: Integer, desc: 'The id of the student project to upload the alignment to'
  end
  post '/units/:unit_id/learning_alignments/csv' do
    ensure_csv!(params[:file][:tempfile])

    unit = Unit.find(params[:unit_id])

    unless authorise?(current_user, unit, :get_unit)
      error!({ error: 'You are not authorised to access this unit.' }, 403)
    end

    if params[:project_id].nil?
      unless authorise? current_user, unit, :upload_csv
        error!({ error: "Not authorised to upload CSV of task alignment to #{unit.code}" }, 403)
      end

      # Actually import...
      unit.import_task_alignment_from_csv(params[:file][:tempfile], nil)
    else
      proj = unit.projects.find(params[:project_id])
      unless authorise?(current_user, proj, :make_submission)
        error!({ error: 'You are not authorised to access this project.' }, 403)
      end

      unit.import_task_alignment_from_csv(params[:file][:tempfile], proj)
    end
  end

  desc "Add an outcome to a unit's task definition"
  params do
    requires :unit_id, type: Integer, desc: 'The id of the unit'
    requires :learning_outcome_id, type: Integer, desc: 'The id of the learning outcome'
    requires :task_definition_id, type: Integer, desc: 'The id of the task definition'
    optional :project_id, type: Integer, desc: 'The id of the project if this is a self reflection'
    requires :description, type: String, desc: 'The ILO''s description'
    requires :rating, type: Integer, desc: 'The rating for this link, indicating the strength of this alignment'
  end
  post '/units/:unit_id/learning_alignments' do
    unit = Unit.find(params[:unit_id])

    # if there is no project -- then this is a unit LO link
    # so need to check the user is authorised to update the unit...
    if params[:project_id].nil? && !authorise?(current_user, unit, :update)
      error!({ error: 'You are not authorised to create task alignments in this unit.' }, 403)
    end

    unit.learning_outcomes.find(params[:learning_outcome_id])

    task_def = unit.task_definitions.find(params[:task_definition_id])

    link_parameters = ActionController::Parameters.new(params)
                                                  .permit(
                                                    :task_definition_id,
                                                    :learning_outcome_id,
                                                    :description,
                                                    :rating
                                                  )

    unless params[:project_id].nil?
      project = unit.projects.find(params[:project_id])
      task = project.task_for_task_definition(task_def)

      unless authorise?(current_user, task, :make_submission)
        error!({ error: 'You are not authorised to create outcome alignments for this task.' }, 403)
      end

      link_parameters[:task_id] = task.id
    end

    result = LearningOutcomeTaskLink.create! link_parameters
    present result, with: Entities::TaskOutcomeAlignmentEntity
  end

  desc 'Update the alignment between a task and unit outcome'
  params do
    requires :id, type: Integer, desc: 'The id of the task alignment'
    requires :unit_id, type: Integer, desc: 'The id of the unit'
    optional :description, type: String, desc: 'The description of the alignment'
    optional :rating, type: Integer, desc: 'The rating for this link, indicating the strength of this alignment'
  end
  put '/units/:unit_id/learning_alignments/:id' do
    unit = Unit.find(params[:unit_id])

    align = unit.learning_outcome_task_links.find(params[:id])

    link_parameters = ActionController::Parameters.new(params)
                                                  .permit(
                                                    :description,
                                                    :rating
                                                  )

    # is this a project task alignment update?
    if !align.task_id.nil?
      task = align.task

      unless authorise?(current_user, task, :make_submission)
        error!({ error: 'You are not authorised to update outcome alignments for this task.' }, 403)
      end

    # else, this is a unit alignment update!
    elsif !authorise?(current_user, unit, :update)
      error!({ error: 'You are not authorised to update the task alignments in this unit.' }, 403)
    end

    align.update(link_parameters)
    align.save!
    present align, with: Entities::TaskOutcomeAlignmentEntity
  end

  desc 'Delete the alignment between a task and unit outcome'
  params do
    requires :id, type: Integer, desc: 'The id of the task alignment'
    requires :unit_id, type: Integer, desc: 'The id of the unit'
  end
  delete '/units/:unit_id/learning_alignments/:id' do
    unit = Unit.find(params[:unit_id])

    align = unit.learning_outcome_task_links.find(params[:id])

    # is this a project task alignment update?
    if !align.task_id.nil?
      task = align.task

      unless authorise?(current_user, task, :make_submission)
        error!({ error: 'You are not authorised to update outcome alignments for this task.' }, 403)
      end

    # else, this is a unit alignment update!
    elsif !authorise?(current_user, unit, :update)
      error!({ error: 'You are not authorised to update the task alignments in this unit.' }, 403)
    end

    align.destroy!
    nil
  end

  desc 'Return unit learning alignment median values'
  params do
    requires :unit_id, type: Integer, desc: 'The id of the unit'
  end
  get '/units/:unit_id/learning_alignments/class_stats' do
    unit = Unit.find(params[:unit_id])

    unless authorise?(current_user, unit, :get_unit)
      error!({ error: 'You are not authorised to access these task alignments.' }, 403)
    end

    present unit.ilo_progress_class_stats
  end

  desc 'Return unit learning alignment values with median stats for each tutorial'
  params do
    requires :unit_id, type: Integer, desc: 'The id of the unit'
  end
  get '/units/:unit_id/learning_alignments/class_details' do
    unit = Unit.find(params[:unit_id])

    unless authorise?(current_user, unit, :get_students)
      error!({ error: 'You are not authorised to access these task alignments.' }, 403)
    end

    present unit.ilo_progress_class_details
  end
end
