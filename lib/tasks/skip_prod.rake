# lib/tasks/skip_prod.rake
# See: http://nithinbekal.com/posts/safe-rake-tasks/

desc 'Raises exception if used in production'
task skip_prod: [:environment] do
  raise 'You cannot run this in production' if Rails.env.production?
end

['db:drop', 'db:reset', 'db:seed'].each do |t|
    Rake::Task[t].enhance ['skip_prod']
end