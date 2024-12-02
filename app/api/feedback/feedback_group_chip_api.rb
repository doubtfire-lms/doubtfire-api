require 'grape'

module Feedback
  class FeedbackGroupChipApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Get all feedback chips'
    get '/feedback_group_chips' do
      chips = FeedbackGroupChip.all
      present chips, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Get all feedback chips for a specific learning_outcome_id'
    params do
      requires :learning_outcome_id, type: Integer, desc: 'The learning_outcome_id of the feedback chips'
    end
    get '/feedback_group_chips/learning_outcome/:learning_outcome_id' do
      chips = FeedbackGroupChip.where(learning_outcome_id: params[:learning_outcome_id])
      present chips, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Get all feedback chips for a specific parent chip'
    params do
      requires :parent_chip_id, type: Integer, desc: 'The parentChipId of the feedback chips'
    end
    get '/feedback_group_chips/parent_chip_id/:parent_chip_id' do
      chips = FeedbackGroupChip.where(parent_chip_id: params[:parent_chip_id])
      present chips, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Get a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
    end
    get '/feedback_group_chips/:id' do
      chip = FeedbackGroupChip.find(params[:id])
      present chip, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Add a feedback chip'
    params do
      requires :chip_text, type: String, desc: 'The title of the feedback chip'
      requires :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback chip'
      requires :learning_outcome_id, type: Integer, desc: 'The learning outcome of the feedback chip'
    end
    post '/feedback_group_chips' do
      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to create feedback template chips.' }, 403)
      end

      chip = FeedbackGroupChip.create(declared(params))
      present chip, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Update a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
      requires :chip_text, type: String, desc: 'The title of the feedback chip'
      requires :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback chip'
      requires :learning_outcome_id, type: Integer, desc: 'The learning_outcome of the feedback chip'
    end
    put '/feedback_group_chips/:id' do
      chip = FeedbackGroupChip.find(params[:id])

      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to create feedback template chips.' }, 403)
      end

      chip.update(declared(params))
      present chip, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Delete a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
    end
    delete '/feedback_group_chips/:id' do
      chip = FeedbackGroupChip.find(params[:id])

      unless authorise? current_user, User, :feedback_chips
        error!({ error: 'You are not authorised to create feedback template chips.' }, 403)
      end

      chip.destroy
      nil
    end
  end
end
