require 'grape'

class LtiApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers LtiHelper
  helpers SidekiqHelper
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

    # if current_user.role_id != Role.student_id
    #   return status 204
    # end

    # role = unit.role_for(current_user)
    # if !role.nil? && role != Role.student
    #   # error!({ error: 'Failed to enrol, user is already staff.' }, 400)
    #   return status 204
    # end

    unit_role = Doubtfire::Application.config.institution_settings.should_employ_lti_member(member)
    unless unit_role.nil?
      unit.employ_staff(current_user, unit_role)
    end

    unless Doubtfire::Application.config.institution_settings.should_enrol_lti_member(member)
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

    job_id = ImportStudentsLtiJob.perform_async(unit.id, token['members'])
    job = setup_job(job_id)
    present job, with: Entities::SidekiqJobEntity
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

  desc 'Issue a one-time login token so an embedded LTI session can open OnTrack in its own tab'
  params do
    requires :ltik, type: String, desc: 'LtiKey asserting the launch user of an active LTI session'
  end
  post '/lti/app-handoff' do
    authenticated?

    token = decode_lti_token(params[:ltik])

    # Stops other LTI tokens, such as enrolment requests, being replayed here.
    unless token['purpose'] == 'app_handoff'
      error!({ error: 'Invalid LTI token.' }, 403)
    end

    launch_email = token['email'].to_s.strip
    if launch_email.empty? || !current_user.email.to_s.casecmp?(launch_email)
      logger.warn "Rejected LTI app handoff for #{current_user.username} from #{request.ip}"
      error!({ error: 'This OnTrack session does not belong to the LMS user who launched OnTrack. Relaunch OnTrack from the LMS.' }, 403)
    end

    onetime_token = current_user.generate_temporary_authentication_token!
    logger.info "LTI app handoff for #{current_user.username} from #{request.ip}"

    present :username, current_user.username
    present :auth_token, onetime_token.authentication_token
  end
end
