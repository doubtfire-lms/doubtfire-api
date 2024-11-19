require 'grape'

module Feedback
  class FeedbackGroupChipApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Get all feedback chips'
    get '/feedback_chips' do
      chips = FeedbackGroupChip.all
      present chips, with: Entities::FeedbackChipEntity
    end

    desc 'Get all feedback chips for a specific belongs_to'
    params do
      requires :belongs_to, type: String, desc: 'The belongs_to of the feedback chips'
    end
    get '/feedback_chips/belongs_to/:belongs_to' do
      chips = FeedbackGroupChip.where(belongs_to: params[:belongs_to])
      present chips, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Get all feedback chips for a specific belongs_to_tlo'
    params do
      requires :belongs_to_tlo, type: String, desc: 'The belongs_to_tlo of the feedback chips'
    end
    get '/feedback_chips/belongs_to_tlo/:belongs_to_tlo' do
      chips = FeedbackGroupChip.where(belongs_to_tlo: params[:belongs_to_tlo])
      present chips, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Get all feedback chips for a specific parent chip'
    params do
      requires :parent_chip_id, type: Integer, desc: 'The parentChipId of the feedback chips'
    end
    get '/feedback_chips/parent_chip_id/:parent_chip_id' do
      chips = FeedbackGroupChip.where(parent_chip_id: params[:parent_chip_id])
      present chips, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Get a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
    end
    get '/feedback_chips/:id' do
      chip = FeedbackGroupChip.find(params[:id])
      present chip, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Add a feedback chip'
    params do
      requires :title, type: String, desc: 'The title of the feedback chip'
      requires :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback chip'
      requires :child_chip_id, type: Integer, desc: 'The child chip ID of the feedback chip'
      requires :belongs_to, type: String, desc: 'The belongs to of the feedback chip'
      requires :belongs_to_tlo, type: String, desc: 'The belongs to TLO of the feedback chip'
    end
    post '/feedback_chips' do
      unless authorise? current_user, FeedbackChip, :create
        error!({ error: 'You are not authorised to create feedback chips.' }, 403)
      end

      chip = FeedbackGroupChip.create(declared(params))
      present chip, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Update a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
      requires :title, type: String, desc: 'The title of the feedback chip'
      requires :parent_chip_id, type: Integer, desc: 'The parent chip ID of the feedback chip'
      requires :child_chip_id, type: Integer, desc: 'The child chip ID of the feedback chip'
      requires :belongs_to, type: String, desc: 'The belongs to of the feedback chip'
      requires :belongs_to_tlo, type: String, desc: 'The belongs to TLO of the feedback chip'
    end
    put '/feedback_chips/:id' do
      chip = FeedbackGroupChip.find(params[:id])

      unless authorise? current_user, FeedbackChip, :update
        error!({ error: 'You are not authorised to update this feedback chip.' }, 403)
      end

      chip.update(declared(params))
      present chip, with: Entities::FeedbackGroupChipEntity
    end

    desc 'Delete a feedback chip'
    params do
      requires :id, type: Integer, desc: 'The ID of the feedback chip'
    end
    delete '/feedback_chips/:id' do
      chip = FeedbackGroupChip.find(params[:id])

      unless authorise? current_user, FeedbackChip, :destroy
        error!({ error: 'You are not authorised to delete this feedback chip.' }, 403)
      end

      chip.destroy
      nil
    end
  end
end
