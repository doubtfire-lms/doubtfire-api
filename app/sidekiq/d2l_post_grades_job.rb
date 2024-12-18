require 'csv'

class D2lPostGradesJob
  include Sidekiq::Job
  include LogHelper

  def perform(unit_id, user_id)
    unit = Unit.find(unit_id)
    user = User.find(user_id)

    logger.info "Posting grades for unit #{unit.id} by user #{user.id}"

    result = D2lIntegration.post_grades(unit, user)

    CSV.open(D2lIntegration.result_file_path(unit), "wb") do |csv|
      csv << %w[Status Message]
      result.each do |r|
        csv << r.split(",")
      end
    end

    logger.info "Finished posting grades for unit #{unit.id} by user #{user.id}"

    mail = D2lResultMailer.result_message(unit, user)
    mail.deliver if mail.present?

    logger.info "Sent email to user #{user.id} for unit #{unit.id} grade transfer result"
  rescue StandardError => e
    logger.error e
  end
end
