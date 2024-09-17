require 'grape'

module Tii
  class TiiActionApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    include LogHelper

    before do
      authenticated?
    end

    desc 'Get the outstanding turn it in actions'
    params do
      optional :unit_id, type: Integer, desc: 'The id of the unit to filter by', default: nil
      optional :limit, type: Integer, desc: 'The maximum number of actions to return', default: 50
      optional :offset, type: Integer, desc: 'The offset to start from', default: 0
      optional :show_complete, type: Boolean, desc: 'Include complete actions?', default: false
    end
    get '/tii_actions' do
      unit = Unit.find(params[:unit_id]) if params[:unit_id].present?

      unless authorise?(current_user, User, :admin_units) || (unit.present? && authorise?(current_user, unit, :add_task_def))
        error!({ error: 'Not authorised access turn it in actions' }, 403)
      end

      result = if unit.present?
                 unit.tii_actions
               else
                 TiiAction.all
               end

      result = result.where(complete: false) unless params[:show_complete]

      present result.order('updated_at DESC').limit(params[:limit]).offset(params[:offset]), with: Tii::Entities::TiiActionEntity
    end

    desc 'Trigger an action on the given group attachment'
    params do
      requires :action, type: String, desc: 'The action to perform: retry'
      optional :unit_id, type: Integer, desc: 'The id of the unit to filter by', default: nil
    end
    put '/tii_actions/:id' do
      unit = Unit.find(params[:unit_id]) if params[:unit_id].present?

      unless authorise?(current_user, User, :admin_units)
        error!({ error: 'Not authorised to retry tasks' }, 403)
      end

      action = TiiAction.find(params[:id])

      case params[:action]
      when 'retry'
        error!({ error: 'Retry in progress. Please wait.' }, 403) if action.retry
        action.perform_retry
      else
        error!({ error: 'Invalid action' }, 400)
      end
    end
  end
end
