# frozen_string_literal: true

#
# Sends each enrolled student's OnTrack grade to the LMS grade item created when the unit was linked.
# A preview matches LMS members to OnTrack students and reports the grades without sending them.
#
class SyncLmsGradesJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, preview_only)
    total(2)
    at(0, 'Fetching LMS course members')

    unit = Unit.find(unit_id)
    source = LmsIntegration.data_source_for(unit)
    members = source.members
    server = LtiServer.new(unit.id)

    result = { success: [], ignored: [], errors: [] }
    scores = []
    rows_by_user_id = {}
    matched_project_ids = Set.new

    members.each do |lms_member|
      row = { lms_user_id: lms_member[:lms_user_id], username: lms_member[:login_id], email: lms_member[:email], name: lms_member[:name] }
      next unless Doubtfire::Application.config.institution_settings.should_enrol_lti_member(lms_member[:member])

      user = LmsUserMatcher.find_user(login_id: lms_member[:login_id], email: lms_member[:email])
      project = user && unit.projects.find_by(user_id: user.id, enrolled: true)
      if user
        row[:ontrack_username] = user.username
        row[:ontrack_name] = user.name
      end

      if project.nil?
        result[:ignored] << { row: row, message: user ? 'Not enrolled in OnTrack' : 'No matching OnTrack user' }
      elsif project.grade.nil?
        matched_project_ids << project.id
        result[:ignored] << { row: row, message: 'No grade in OnTrack' }
      else
        matched_project_ids << project.id
        row[:grade] = project.grade
        rows_by_user_id[lms_member[:lms_user_id]] = row
        scores << { userId: lms_member[:lms_user_id], scoreGiven: project.grade }
      end
    end

    # Graded OnTrack students with no LMS member would otherwise be skipped silently
    unit.projects.where(enrolled: true).where.not(grade: nil).where.not(id: matched_project_ids.to_a).includes(:user).find_each do |project|
      row = { ontrack_username: project.user.username, ontrack_name: project.user.name, email: project.user.email, grade: project.grade }
      result[:ignored] << { row: row, message: 'Not a student in the LMS course' }
    end

    if preview_only
      rows_by_user_id.each_value { |row| result[:success] << { row: row, message: "Will send: #{row[:grade]}%" } }
    elsif scores.any?
      at(1, "Sending #{scores.length} grades to the LMS")
      Array(server.submit_scores(scores)['results']).each do |score_result|
        row = rows_by_user_id[score_result['userId']]
        if score_result['success']
          result[:success] << { row: row, message: "Grade synced: #{row[:grade]}%" }
        else
          result[:errors] << { row: row, message: score_result['error'] || 'Failed to submit score' }
        end
      end
    end

    at(2, preview_only ? 'Grade sync preview complete' : 'Grade sync complete')
    store(result: result.to_json)
  end
end
