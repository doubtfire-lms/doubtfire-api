# lib/tasks/register_subscribers.rake
# See: http://nithinbekal.com/posts/safe-rake-tasks/

require_relative '../assets/ontrack_receive_action.rb'

desc 'Start listening for responses from Overseer, and update associated tasks'
task register_q_assessment_results_subscriber: [:environment] do
  sm_instance = Doubtfire::Application.config.sm_instance

  if sm_instance.nil?
    puts "ServiceManager is not initialised yet."
    return
  end

  sm_instance.clients[:ontrack].action = method(:receive)
  sm_instance.clients[:ontrack].start_subscriber
  puts "Bye!"
end
