require 'grape'

class LtiApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers LtiHelper
  include LogHelper

  # before do
  #   authenticated?
  # end

  desc 'Returns success if current user is allowed to link requested unit'
  params do
    requires :ltik, type: String, desc: 'LtiKey provided with user info and deeplink resources'
  end
  post '/lti/link' do
    authenticated?

    unless authorise? current_user, User, :convene_units
      error!({ error: "Not authorised to link this unit." }, 403)
    end

    token = decode_lti_token(params[:ltik])

    unit_id = token["unit_id"]
    if unit_id.nil?
      error!({ error: 'Invalid LTI token.' }, 400)
    end

    unit = Unit.find_by(id: unit_id)

    if unit.nil?
      error!({ error: 'Unit does not exist.' }, 404)
    end

    unless authorise? current_user, unit, :enrol_student
      error!({ error: "Not authorised to link this unit." }, 403)
    end

    status 200
  end

  desc 'Enrol a student into a linked Lti unit'
  params do
    requires :ltik, type: String, desc: 'LtiKey provided with user info and deeplink resources'
  end
  post '/lti/enrol' do
    authenticated?

    token = decode_lti_token(params[:ltik])

    unit_id = token["unit_id"]
    if unit_id.nil?
      error!({ error: 'Invalid LTI token.' }, 400)
    end

    unit = Unit.find_by(id: unit_id)
    if unit.nil?
      error!({ error: 'Unit does not exist.' }, 404)
    end

    member = token['member']
    if member.nil?
      error!({ error: 'Invalid LTI token.' }, 400)
    end

    valid_member, missing = valid_lti_member?(member)
    unless valid_member
      error!({ error: "Missing required fields:  #{missing.join(', ')}" }, 400)
    end

    if current_user.role_id != Role.student_id
      return status 204
    end

    role = unit.role_for(current_user)
    if !role.nil? && role != Role.student
      # error!({ error: 'Failed to enrol, user is already staff.' }, 400)
      return status 204
    end

    unless Doubtfire::Application.config.institution_settings.should_enrol_lti_member(token['member'])
      # error!({ error: 'User can not be enrolled into this unit.' }, 404)
      return status 204
    end

    # TODO: which campus?
    project = unit.enrol_student(current_user, nil)

    present project, with: Entities::ProjectEntity, user: current_user, for_student: true, in_project: true
  end

  desc 'Enrol a list of students into a linked Lti unit'
  params do
    requires :ltik, type: String, desc: 'LtiKey provided with unit id and list of members'
    # requires :members, type: Array,
    #   requires :email, type: String
    #   requires :family_name, type: String
    #   requires :given_name, type: String
    #   requires :name, type: String
    #   requires :user_id, type: String
    #   requires :roles, type: Array[String]
    # end
  end
  post '/lti/enrol/bulk' do
    authenticated?

    token = decode_lti_token(params[:ltik])

    unit_id = token["unit_id"]
    if unit_id.nil?
      error!({ error: 'Invalid LTI token.' }, 400)
    end

    unit = Unit.find_by(id: unit_id)
    if unit.nil?
      error!({ error: 'Unit does not exist.' }, 404)
    end

    unless authorise? current_user, unit, :enrol_student
      error!({ error: "Not authorised to link this unit." }, 403)
    end

    result = {
      success: [],
      ignored: [],
      errors: []
    }

    token["members"].each do |member|
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
        project = unit.enrol_student(user, nil)
        if project.valid?
          result[:success] << { row: member, message: "Successfully enrolled user." }
        else
          result[:errors] << { row: member, message: "Failed to enrol student" }
        end
      else
        result[:errors] << { row: member, message: "Failed to create user" }
      end
    rescue StandardError => e
      result[:errors] << { row: member, message: e }
    end
    result
  end

  desc 'Get grades for a list of students'
  params do
    requires :ltik, type: String, desc: 'LtiKey provided with user info and deeplink resources'
  end
  post '/lti/grades' do
    authenticated?

    token = decode_lti_token(params[:ltik])

    unless authorise? current_user, User, :convene_units
      error!({ error: "Not authorised to sync grades." }, 403)
    end

    unit_id = token["unit_id"]
    if unit_id.nil?
      error!({ error: 'Invalid LTI token.' }, 400)
    end

    unit = Unit.find_by(id: unit_id)
    if unit.nil?
      error!({ error: 'Unit does not exist.' }, 404)
    end

    student_emails = token["student_emails"]

    if student_emails.nil?
      error!({ error: 'Student emails field does not exist.' }, 400)
    end

    unless student_emails.is_a?(Array)
      error!({ error: 'Student emails must be an array.' }, 400)
    end

    projects = unit.projects.joins(:user).where(users: { email: student_emails })

    projects_hash = {}

    projects.each do |project|
      projects_hash[project.user.email] = if authorise?(current_user, project, :assess)
                                            project.grade
                                          else
                                            # Let the lti API know that user doesnt have permission to this project
                                            -1
                                          end
    end

    projects_hash
  end
end
