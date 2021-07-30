# lib/tasks/skip_prod.rake
# See: http://nithinbekal.com/posts/safe-rake-tasks/

desc 'Raises exception if used in production'
task skip_prod: [:environment] do
  if Rails.env.production?
    puts "Are you sure you want to run this on production? (Yes to confirm): "
    response = STDIN.gets.chomp

    raise 'You chose not to run this in production' unless response == 'Yes'
  end
end

['db:drop', 'db:reset', 'db:seed'].each do |t|
    Rake::Task[t].enhance ['skip_prod']
end
