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

      unless authorise?(current_user, User, :admin_units) || (unit.present? && authorise?(current_user, unit, :add_task_def))
        error!({ error: 'Not authorised access turn it in actions' }, 403)
      end

      action = if unit.present?
                 unit.tii_actions.find(params[:id])
               else
                 TiiAction.find(params[:id])
               end

      case params[:action]
      when 'retry'
        error!({ error: 'Action already scheduled' }, 403) if TiiActionJob.jobs.any? { |job| job['args'].first == action.id }

        action.perform_async
      else
        error!({ error: 'Invalid action' }, 400)
      end
    end
  end
end
