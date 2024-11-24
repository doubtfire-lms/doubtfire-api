require 'grape'

module Feedback
  class FeedbackTemplateChipApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Get all feedback template chips'
    get '/feedback_template_chips' do
      chips = FeedbackChip.all
      present chips, with: Entities::FeedbackTemplateChipEntity
    end

    desc 'Get a feedback template chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback template chip'
    end
    get '/feedback_template_chips/:id' do
      chip = FeedbackChip.find(params[:id])
      present chip, with: Entities::FeedbackTemplateChipEntity
    end

    desc 'Add a feedback template chip'
    params do
      requires :chip_text, type: String, desc: 'The text of the feedback template chip'
      requires :description, type: String, desc: 'The description of the feedback template chip'
      requires :task_status, type: String, desc: 'The task status of the feedback template chip'
      requires :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback template chip'
      requires :learning_outcome, type: String, desc: 'The learning outcome of the feedback template chip'
      requires :related_entity, type: String, desc: 'The related entity of the feedback template chip'
      requires :section, type: String, desc: 'The section of the feedback template chip'
      requires :comment_text, type: String, desc: 'The comment text of the feedback template chip'
      requires :summary_text, type: String, desc: 'The summary text of the feedback template chip'
    end
    post '/feedback_template_chips' do
      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to create feedback template chips.' }, 403)
      end

      chip = FeedbackChip.create(declared(params))
      present chip, with: Entities::FeedbackTemplateChipEntity
    end

    desc 'Update a feedback template chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback template chip'
      requires :chip_text, type: String, desc: 'The text of the feedback template chip'
      requires :description, type: String, desc: 'The description of the feedback template chip'
      requires :task_status, type: String, desc: 'The task status of the feedback template chip'
      requires :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback template chip'
      requires :learning_outcome, type: String, desc: 'The learning outcome of the feedback template chip'
      requires :related_entity, type: String, desc: 'The related entity of the feedback template chip'
      requires :section, type: String, desc: 'The section of the feedback template chip'
      requires :comment_text, type: String, desc: 'The comment text of the feedback template chip'
      requires :summary_text, type: String, desc: 'The summary text of the feedback template chip'
    end
    put '/feedback_template_chips/:id' do
      chip = FeedbackChip.find(params[:id])

      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to update this feedback template chip.' }, 403)
      end

      chip.update(declared(params))
      present chip, with: Entities::FeedbackTemplateChipEntity
    end

    desc 'Delete a feedback template chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback template chip'
    end
    delete '/feedback_template_chips/:id' do
      chip = FeedbackChip.find(params[:id])

      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to delete this feedback template chip.' }, 403)
      end

      chip.destroy
      nil
    end
  end
end
