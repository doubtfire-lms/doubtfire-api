# lib/tasks/pause_sidekiq.rake
namespace :db do
  desc 'Pauses Sidekiq Queue'
  task pause_sidekiq: [:environment] do
    Sidekiq::ProcessSet.new.each(&:quiet!)
  end
end
