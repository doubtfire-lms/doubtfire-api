require 'grape'

module Tii
  class TiiGroupAttachmentApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    include LogHelper

    desc 'Get the group attachments for a given task definition'
    get '/units/:unit_id/task_definitions/:task_def_id/tii_group_attachments' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised access group attachments for this unit' }, 403)
      end

      task_definition = unit.task_definitions.find(params[:task_def_id])

      present task_definition.tii_group_attachments, with: Tii::Entities::TiiGroupAttachmentEntity
    end

    desc 'Trigger an action on the given group attachment'
    params do
      requires :action, type: String, desc: 'The action to perform: upload'
    end
    put '/units/:unit_id/task_definitions/:task_def_id/tii_group_attachments/:id' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised access group attachments for this unit' }, 403)
      end

      task_definition = unit.task_definitions.find(params[:task_def_id])
      group_attachment = task_definition.tii_group_attachments.find(params[:id])

      case params[:action]
      when 'upload'
        group_attachment.update(status: :has_id)
        action = TiiActionUploadTaskResources.find_or_create_by(entity: group_attachment)
        action.perform_async
        present group_attachment, with: Tii::Entities::TiiGroupAttachmentEntity
      else
        error!({ error: 'Invalid action' }, 400)
      end
    end

    desc 'Delete a group attachment'
    delete '/units/:unit_id/task_definitions/:task_def_id/tii_group_attachments/:id' do
      unit = Unit.find(params[:unit_id])

      unless authorise? current_user, unit, :add_task_def
        error!({ error: 'Not authorised access group attachments for this unit' }, 403)
      end

      task_definition = unit.task_definitions.find(params[:task_def_id])
      group_attachment = task_definition.tii_group_attachments.find(params[:id])

      group_attachment.destroy!
      group_attachment.destroyed?
    end
  end
end
