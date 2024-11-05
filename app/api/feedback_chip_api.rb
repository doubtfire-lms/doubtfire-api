require 'grape'

class FeedbackChipApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Get all feedback chips'
  get '/feedback_chips' do
    chips = FeedbackChip.all
    present chips, with: Entities::FeedbackChipEntity
  end

  desc 'Get all feedback chips for a specific belongsTo'
  params do
    requires :belongsTo, type: String, desc: 'The belongsTo of the feedback chips'
  end
  get '/feedback_chips/belongs_to/:belongsTo' do
    chips = FeedbackChip.where(belongsTo: params[:belongsTo])
    present chips, with: Entities::FeedbackChipEntity
  end

  desc 'Get all feedback chips for a specific parent chip'
  params do
    requires :parentChipId, type: Integer, desc: 'The parentChipId of the feedback chips'
  end
  get '/feedback_chips/parent_chip_id/:parentChipId' do
    chips = FeedbackChip.where(parentChipId: params[:parentChipId])
    present chips, with: Entities::FeedbackChipEntity
  end

  desc 'Get a feedback chip'
  params do
    requires :id, type: Integer, desc: 'The ID of the feedback chip'
  end
  get '/feedback_chips/:id' do
    chip = FeedbackChip.find(params[:id])
    present chip, with: Entities::FeedbackChipEntity
  end

  desc 'Add a feedback chip'
  params do
    requires :title, type: String, desc: 'The title of the feedback chip'
    requires :parentChipId, type: Integer, desc: 'The parent chip ID of the feedback chip'
    requires :childChipId, type: Integer, desc: 'The child chip ID of the feedback chip'
    requires :belongsTo, type: String, desc: 'The belongs to of the feedback chip'
  end
  post '/feedback_chips' do
    unless authorise? current_user, FeedbackChip, :create
      error!({ error: 'You are not authorised to create feedback chips.' }, 403)
    end

    chip = FeedbackChip.create(declared(params))
    present chip, with: Entities::FeedbackChipEntity
  end

  desc 'Update a feedback chip'
  params do
    requires :id, type: Integer, desc: 'The ID of the feedback chip'
    requires :title, type: String, desc: 'The title of the feedback chip'
    requires :parentChipId, type: Integer, desc: 'The parent chip ID of the feedback chip'
    requires :childChipId, type: Integer, desc: 'The child chip ID of the feedback chip'
    requires :belongsTo, type: String, desc: 'The belongs to of the feedback chip'
  end
  put '/feedback_chips/:id' do
    chip = FeedbackChip.find(params[:id])

    unless authorise? current_user, chip, :update
      error!({ error: 'You are not authorised to update this feedback chip.' }, 403)
    end

    chip.update(declared(params))
    present chip, with: Entities::FeedbackChipEntity
  end

  desc 'Delete a feedback chip'
  params do
    requires :id, type: Integer, desc: 'The ID of the feedback chip'
  end
  delete '/feedback_chips/:id' do
    chip = FeedbackChip.find(params[:id])

    unless authorise? current_user, chip, :destroy
      error!({ error: 'You are not authorised to delete this feedback chip.' }, 403)
    end

    chip.destroy
    nil
  end
end
