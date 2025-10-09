module Entities
  class MarkingSessionEntity < Grape::Entity
    expose :id
    expose :user_id
    expose :unit_id
    expose :start_time
    expose :end_time
    # TODO: duration_minutes should be a marking_session method not a schema field
    expose :duration_minutes

    expose :comments_added do |session, _options|
      session.session_activities.count { |act| act.action == 'add-comment' }
    end

    expose :assessments do |session, _options|
      session.session_activities.count { |act| act.action == 'assessing' }
    end

    expose :submissions_opened do |session, _options|
      session.session_activities.count { |act| act.action == 'get-submission-details' }
    end
  end
end
