require 'csv'

class ImportStudentsLtiJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper
  include MimeCheckHelpers
  include CsvHelper
  include LtiHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, members)
    logger.info "Starting user imports... (Lti)"

    at(0)
    total(members.count)

    unit = Unit.find(unit_id)

    result = {
      success: [],
      ignored: [],
      errors: []
    }

    members.each_with_index do |member, i|
      at(i)
      valid_member, missing = valid_lti_member?(member)
      unless valid_member
        result[:ignored] << { row: member, message: "Missing required fields: #{missing.join(', ')}" }
        next
      end

      user_id_data = {
        login_id: member["user_id"],
        email: member["email"],
        username: member["email"][/(.*)@/, 1]
      }

      user = User.find_by(login_id: user_id_data[:login_id]) ||
             User.find_by(username: user_id_data[:username]) ||
             User.find_by(email: user_id_data[:email]) ||
             User.create do |new_user|
               # Update new user with details from the SAML response
               Doubtfire::Application.config.institution_settings.update_user_from_lti_response(
                 new_user,
                 user_id_data,
                 member
               )
             end

      if user.valid?
        unit_role = Doubtfire::Application.config.institution_settings.should_employ_lti_member(member)
        unless unit_role.nil?
          staff = unit.employ_staff(user, unit_role)
          if staff.valid?
            result[:success] << { row: member, message: "Successfully added staff (#{unit_role.name})" }
          end
        end

        unless Doubtfire::Application.config.institution_settings.should_enrol_lti_member(member)
          result[:ignored] << { row: member, message: "Enrolment skipped by institution setting" }
          next
        end

        project = unit.enrol_student(user, nil)
        if project.valid?
          result[:success] << { row: member, message: "Successfully enrolled user" }
        else
          result[:errors] << { row: member, message: "Failed to enrol student" }
        end
      else
        result[:errors] << { row: member, message: "Failed to create user" }
      end
    rescue StandardError => e
      result[:errors] << { row: member, message: e }
    end

    store(result: result.to_json)

    logger.info "Completed user imports (Lti)!"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
