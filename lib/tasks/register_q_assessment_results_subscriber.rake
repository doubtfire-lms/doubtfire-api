# lib/tasks/register_subscribers.rake
# See: http://nithinbekal.com/posts/safe-rake-tasks/

require_relative '../assets/ontrack_receive_action.rb'

desc 'Register a subscriber bound to queue q_assessment_results'
task register_q_assessment_results_subscriber: [:environment] do
  sm_instance = Doubtfire::Application.config.sm_instance

  if sm_instance.nil?
    puts "ServiceManager is not initialised yet."
    return
  end

  sm_instance.clients[:ontrack].action = method(:receive)
  sm_instance.clients[:ontrack].start_subscriber

end
