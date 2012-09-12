set :output, "/path/to/my/cron_log.log"

every 1.minutes do
  command "echo hi >> /Users/ajones/test.txt"
end
