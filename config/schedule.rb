set :output, "#{path}/log/cron.log"

every 1.day, at: '3:00 am' do
  rake 'db:update_temporal'
end
