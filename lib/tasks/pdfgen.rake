require_relative '../assets/ontrack_receive_action.rb'

namespace :submission do
  desc 'Start listening for tasks in tasks.submission, then convert to pdf'
  task pdfgen: [:environment] do
    sm_instance = Doubtfire::Application.config.sm_instance

    if sm_instance.nil?
      puts "ServiceManager is not initialised."
      return
    end

    sm_instance.clients[:ontrack].action = method(:receive)
    sm_instance.clients[:ontrack].start_subscriber

    task = Task.find(params[:task_id])

    begin
      logger.info "creating pdf for task #{task.id}"
      task_pdf = task.convert_submission_to_pdf

    rescue Exception => e
      add_error.call(e.message.to_s)
    end

    puts "Bye!"
  end
end
