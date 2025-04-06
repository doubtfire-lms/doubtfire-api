require 'grape'

#
# API endpoint for staff to grant extensions to multiple students at once
#
class StaffGrantExtensionApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers DbHelpers

  before do
    authenticated?
    error!({
      error: 'Not authorized to grant extensions',
      code: 'UNAUTHORIZED',
      details: {}
    }, 403) unless current_user.has_tutor_capability?
  end

  desc 'Grant extensions to multiple students',
       detail: 'This endpoint allows staff to grant extensions to multiple students at once for a specific task. The operation is atomic - either all extensions are granted or none are. Students not found in the unit are automatically skipped without affecting the transaction.',
       success: [
         { code: 201, message: 'Extensions granted successfully' }
       ],
       failure: [
         { code: 400, message: 'Some extensions failed to be granted' },
         { code: 403, message: 'Not authorized to grant extensions for this unit' },
         { code: 404, message: 'Unit or task definition not found' },
         { code: 500, message: 'Internal server error' }
       ],
       response: {
         successful: [
           {
             student_id: 'Integer - ID of the student',
             project_id: 'Integer - ID of the project',
             weeks_requested: 'Integer - Number of weeks extension granted',
             extension_response: 'String - Human readable message with new due date',
             task_status: 'String - Updated status of the task'
           }
         ],
         failed: [
           {
             student_id: 'Integer - ID of the student',
             project_id: 'Integer - ID of the project',
             error: 'String - Error message explaining why extension failed'
           }
         ],
         skipped: [
           {
             student_id: 'Integer - ID of the student',
             reason: 'String - Reason why the student was skipped'
           }
         ]
       }
  params do
    requires :student_ids, type: Array[Integer], desc: 'List of student IDs to grant extensions to'
    requires :task_definition_id, type: Integer, desc: 'Task definition ID'
    requires :weeks_requested, type: Integer, desc: 'Number of weeks to extend by'
    requires :comment, type: String, desc: 'Reason for extension'
  end
  post '/units/:unit_id/staff-grant-extension' do
    unit = Unit.find(params[:unit_id])
    task_definition = unit.task_definitions.find(params[:task_definition_id])

    # Use transaction to ensure atomic operation
    ActiveRecord::Base.transaction do
      results = {
        successful: [],
        failed: [],
        skipped: []
      }

      params[:student_ids].each do |student_id|
        # Find project for this student in the unit
        project = unit.projects.find_by(user_id: student_id)
        if project.nil?
          results[:skipped] << {
            student_id: student_id,
            reason: 'Student not found in unit'
          }
          next
        end

        result = ExtensionService.grant_extension(
          project.id,
          task_definition.id,
          current_user,
          params[:weeks_requested],
          params[:comment],
          true # is_staff_grant = true
        )

        if result[:success]
          extension_comment = result[:result]
          results[:successful] << {
            student_id: student_id,
            project_id: project.id,
            weeks_requested: extension_comment.extension_weeks,
            extension_response: extension_comment.extension_response,
            task_status: extension_comment.task.status
          }
        else
          results[:failed] << {
            student_id: student_id,
            project_id: project.id,
            error: result[:error]
          }
          # If it's a validation error (403), raise it immediately
          error!({ error: result[:error] }, result[:status]) if result[:status] == 403
        end
      end

      # If any extensions failed (but not due to validation), rollback the entire transaction
      if results[:failed].any?
        error!({ error: 'Some extensions failed to be granted', results: results }, 400)
      end

      status 201
      present results, with: Grape::Presenters::Presenter
    end
  rescue ActiveRecord::RecordNotFound
    error!({ error: 'Unit or task definition not found' }, 404)
  rescue StandardError
    error!({ error: 'An unexpected error occurred' }, 500)
  end
end
