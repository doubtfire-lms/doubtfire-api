namespace :mailer do
  desc 'Create this week\'s opted-in summary notifications without sending legacy emails'
  task send_status_emails: :environment do
    CreateWeeklySummaryNotificationsJob.new.perform_now
  end
end
