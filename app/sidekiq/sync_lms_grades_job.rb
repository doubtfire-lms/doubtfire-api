# frozen_string_literal: true

#
# Sends each enrolled student's OnTrack grade to the LMS grade item created when the unit was linked.
#
class SyncLmsGradesJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id)
    total(2)
    at(0, 'Fetching LMS course members')

    unit = Unit.find(unit_id)
    source = LmsIntegration.data_source_for(unit)
    members = source.members
    server = LtiServer.new(unit.id)

    result = { success: [], ignored: [], errors: [] }
    scores = []
    rows_by_user_id = {}

    members.each do |lms_member|
      row = { username: lms_member[:login_id], email: lms_member[:email], name: lms_member[:name] }
      next unless Doubtfire::Application.config.institution_settings.should_enrol_lti_member(lms_member[:member])

      user = LmsUserMatcher.find_user(login_id: lms_member[:login_id], email: lms_member[:email])
      project = user && unit.projects.find_by(user_id: user.id, enrolled: true)
      if project.nil?
        result[:ignored] << { row: row, message: 'Not enrolled in OnTrack' }
      elsif project.grade.nil?
        result[:ignored] << { row: row, message: 'No grade in OnTrack' }
      else
        row[:grade] = project.grade
        rows_by_user_id[lms_member[:lms_user_id]] = row
        scores << { userId: lms_member[:lms_user_id], scoreGiven: project.grade }
      end
    end

    at(1, "Sending #{scores.length} grades to the LMS")
    if scores.any?
      Array(server.submit_scores(scores)['results']).each do |score_result|
        row = rows_by_user_id[score_result['userId']]
        if score_result['success']
          result[:success] << { row: row, message: "Grade synced: #{row[:grade]}%" }
        else
          result[:errors] << { row: row, message: score_result['error'] || 'Failed to submit score' }
        end
      end
    end

    at(2, 'Grade sync complete')
    store(result: result.to_json)
  end
end
