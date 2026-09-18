namespace :notifications do
  desc 'Warn students about stale Discuss tasks and expire overdue Discuss tasks'
  task notify_discuss_timeout: :environment do
    count = Unit.notify_discuss_timeouts!
    Rails.logger.info "Discuss timeout notification pass created #{count} comment(s)."
  end
end
