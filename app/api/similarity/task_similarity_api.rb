require 'grape'

module Similarity
  class TaskSimilarityApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Get all the task similarities for a task'
    get '/tasks/:task_id/similarities' do
      unless authenticated?
        error!({ error: "Not authorised to download details for task '#{params[:id]}'" }, 401)
      end
      task = Task.find(params[:task_id])

      unless authorise? current_user, task, :view_plagiarism
        error!({ error: "Not authorised to download details for task '#{params[:id]}'" }, 401)
      end

      present task.task_similarities, with: Similarity::Entities::TaskSimilarityEntity, my_role: task.unit.role_for(current_user)
    end

    desc 'Update a task similarity - switching flag only'
    params do
      requires :id, type: Integer, desc: 'ID of similarity to update.'
      requires :task_id, type: Integer, desc: 'ID of task to update similarity for.'
      requires :flagged, type: Boolean, desc: 'Whether or not to flag the similarity.'
    end
    put '/tasks/:task_id/similarities/:id' do
      unless authenticated?
        error!({ error: "Not authorised to download details for task" }, 401)
      end
      task = Task.find(params[:task_id])

      unless authorise? current_user, task, :delete_plagiarism
        error!({ error: "Not authorised to update details for this similarity" }, 401)
      end

      similarity = task.task_similarities.find(params[:id])
      similarity.update(flagged: params[:flagged])

      present similarity, with: Similarity::Entities::TaskSimilarityEntity, my_role: task.unit.role_for(current_user)
    end

    desc 'Get contents of a similarity by part index'
    params do
      optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
      requires :idx, type: Integer, desc: 'Index of part to download. 0 is the first part, 1 is the second part. For MOSS Similarity'
      requires :id, type: Integer, desc: 'ID of similarity to download.'
      requires :task_id, type: Integer, desc: 'ID of task to download similarity for.'
    end
    get '/tasks/:task_id/similarities/:id/contents/:idx' do
      unless authenticated?
        error!({ error: "Not authorised to download details for task '#{params[:id]}'" }, 401)
      end
      task = Task.find(params[:task_id])

      unless authorise? current_user, task, :view_plagiarism
        error!({ error: "Not authorised to download details for task '#{params[:id]}'" }, 401)
      end

      similarity = task.task_similarities.find(params[:id])

      if similarity.type == 'MossTaskSimilarity'
        if params[:idx] == 0
          content_type 'text/html'
          path = FileHelper.path_to_plagarism_html(similarity)
          filename = "#{similarity.student.username}_#{similarity.other_student&.username}_#{similarity.pct}.html"
        elsif params[:idx] == 1 && authorise?(current_user, similarity.other_task, :view_plagiarism)
          content_type 'text/html'
          path = FileHelper.path_to_plagarism_html(similarity.other_similarity) if similarity.other_similarity.present?
          filename = "#{similarity.other_student&.username}_#{similarity.student.username}_#{similarity.other_similarity&.pct}.html"
        else
          error!({ error: "No details to download for task '#{params[:id]}'" }, 404)
        end
      else
        content_type 'application/pdf'
        path = similarity.similarity_pdf_path
      end

      if File.exist?(path)
        if params[:as_attachment]
          header['Content-Disposition'] = "attachment; filename=#{filename}"
          header['Access-Control-Expose-Headers'] = 'Content-Disposition'
        end

        env['api.format'] = :binary

        File.read(path)
      else
        error!({ error: "No details to download for task '#{params[:id]}'" }, 404)
      end
    end

    desc 'Get viewer url for a turn it in similarity'
    params do
      requires :id, type: Integer, desc: 'ID of similarity to get viewer url for.'
      requires :task_id, type: Integer, desc: 'ID of task to get similarity for.'
    end
    get '/tasks/:task_id/similarities/:id/viewer_url' do
      unless authenticated?
        error!({ error: "Not authorised to download details for task '#{params[:id]}'" }, 401)
      end
      task = Task.find(params[:task_id])

      unless authorise? current_user, task, :view_plagiarism
        error!({ error: "Not authorised to download details for task '#{params[:id]}'" }, 401)
      end

      similarity = task.task_similarities.find(params[:id])

      if similarity.present? && similarity.type == 'TiiTaskSimilarity'
        if similarity.ready_for_viewer?
          result = similarity.create_viewer_url(current_user)
          error!({ error: 'Report viewer not currently available, please try again later' }, 503) if result.blank?
          present result, with: Grape::Presenters::Presenter
        else
          error!({ error: "Similarity report is not yet ready to be viewed for this submission" }, 404)
        end
      else
        similarity.plagiarism_report_url
      end
    end
  end
end
