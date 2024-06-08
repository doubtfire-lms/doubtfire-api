module TimeoutHelper
  extend LogHelper

  #
  # Timeout operation
  #
  # Usage:
  #   try_within 30, "doing the thing" do
  #     long_operation()
  #   end
  #
  def try_within(sec, timeout_message = 'operation')
    begin
      Timeout::timeout(sec) { yield }
    rescue
      logger.error "Timeout when #{timeout_message} after #{sec}s"
    end
  end

  #
  # Timeout system call
  #
  # Usage:
  #   system_try_within 30, "doing the thing", "gs do.pdf the.pdf thing.pdf"
  #
  def system_try_within(sec, timeout_message, command)
    # shell script to kill command after timeout
    timeout_exec = Rails.root.join('lib/shell/timeout.sh')
    result = false
    try_within sec, timeout_message do
      result = system "#{timeout_exec} -t #{sec} nice -n 10 #{command}"
    end
    result
  end

  # Export functions as module functions
  module_function :try_within
  module_function :system_try_within
end
