require 'grape'
module Feedback
  class FeedbackChipApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get all feedback chips for a context"
    get '/:context_type_plural/:context_id/feedback_chips' do
      context_type = params[:context_type_plural].singularize.camelize
      context_model = context_type.classify.constantize.find(params[:context_id])

      unless authorise? current_user, context_model, :get_los
        error!({ error: 'You are not authorised to view feedback chips in this context.' }, 403)
      end

      learning_outcomes = context_model.learning_outcomes
      feedback_chips = FeedbackChip.where(learning_outcome_id: learning_outcomes.pluck(:id))
      present feedback_chips, with: Feedback::Entities::FeedbackChipEntity
    end

    desc 'Add a feedback chip to a learning outcome'
    params do
      requires :chip_text, type: String, desc: 'The title of the feedback chip'
      optional :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback chip'
      requires :learning_outcome_id, type: Integer, desc: 'The learning outcome of the feedback chip'
      requires :description, type: String, desc: 'The description of the feedback chip'
      optional :task_status, type: String, desc: 'The task status of the feedback template chip'
      optional :comment_text, type: String, desc: 'The comment text of the feedback template chip'
      optional :summary_text, type: String, desc: 'The summary text of the feedback template chip'
      requires :type, type: String, desc: 'The type of the feedback chip (template or group)'
    end
    post '/feedback_chips' do
      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to create feedback chips.' }, 403)
      end

      chip_class = params[:type] == 'template' ? FeedbackTemplateChip : FeedbackGroupChip
      chip = chip_class.create(declared(params, include_missing: false).except(:type))
      entity = params[:type] == 'template' ? Entities::FeedbackTemplateChipEntity : Entities::FeedbackGroupChipEntity
      present chip, with: entity
    end

    desc 'Update a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
      optional :chip_text, type: String, desc: 'The title of the feedback chip'
      optional :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback chip'
      optional :learning_outcome_id, type: Integer, desc: 'The learning outcome of the feedback chip'
      optional :description, type: String, desc: 'The description of the feedback chip'
      optional :task_status, type: String, desc: 'The task status of the feedback template chip'
      optional :comment_text, type: String, desc: 'The comment text of the feedback template chip'
      optional :summary_text, type: String, desc: 'The summary text of the feedback template chip'
      optional :type, type: String, desc: 'The type of the feedback chip (template or group)'
    end
    put '/feedback_chips/:id' do
      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to update feedback chips.' }, 403)
      end

      chip = FeedbackChip.find(params[:id])

      if params[:type] == 'template'
        chip.update(type: 'Feedback::FeedbackTemplateChip')
      elsif params[:type] == 'group'
        chip.update(type: 'Feedback::FeedbackGroupChip')
      else
        error!({ error: 'Invalid feedback chip type' }, 400)
      end

      chip.update(declared(params, include_missing: false).except(:type))
      entity = chip.type == 'Feedback::FeedbackTemplateChip' ? Entities::FeedbackTemplateChipEntity : Entities::FeedbackGroupChipEntity
      present chip, with: entity
    end

    desc 'Delete a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
    end
    delete '/feedback_chips/:id' do
      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to delete feedback chips.' }, 403)
      end

      chip = FeedbackChip.find(params[:id])
      chip.destroy
      nil
    end

    desc 'Track usage of a feedback template chip by a tutor'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback template chip'
      requires :tutor_id, type: Integer, desc: 'The ID of the tutor'
    end
    post '/feedback_template_chip/:id/track_usage' do
      chip = FeedbackTemplateChip.find(params[:id])
      tutor = Tutor.find(params[:tutor_id])
      chip.track_usage_by_tutor(tutor)
      nil
    end

    desc 'Download the feedback chips for a specific outcome'
    params do
      requires :id, type: Integer, desc: 'The ID of the context'
    end
    get '/:context_type_plural/:context_id/outcomes/:id/feedback_chips/csv' do
      # find context model dynamically
      context_type = params[:context_type_plural].singularize.camelize
      context_model = context_type.classify.constantize.find(params[:context_id])
      learning_outcome = LearningOutcome.find(params[:id])

      unless authorise? current_user, context_model, :update
        error!({ error: 'You are not authorised to download feedback chips in this context.' }, 403)
      end

      title = learning_outcome.abbreviation

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{title}--Feedback_Chips.csv"
      header['Access-Control-Expose-Headers'] = 'Content-Disposition'
      env['api.format'] = :binary
      learning_outcome.export_feedback_chips_to_csv
    end

    desc 'Upload the feedback chips for a specified outcome from a csv'
    params do
      requires :file, type: File, desc: 'CSV upload file.'
      requires :id, type: Integer, desc: 'The id of the learning outcome'
    end
    post '/:context_type_plural/:context_id/outcomes/:id/feedback_chips/csv' do
      # check mime is correct before uploading
      ensure_csv!(params[:file][:tempfile])

      # find context model dynamically
      learning_outcome = LearningOutcome.find(params[:id])

      unless authorise? current_user, learning_outcome, :upload_csv
        error!({ error: 'Not authorised to upload CSV of outcomes' }, 403)
      end

      # Actually import...
      learning_outcome.import_feedback_chips_from_csv(params[:file][:tempfile])
    end

  end
end
