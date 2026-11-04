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
  #   system_try_within 30, "doing the thing", ['gs', 'do.pdf', 'the.pdf', 'thing.pdf']
  #
  def system_try_within(sec, timeout_message, command)
    raise ArgumentError, 'command must be an argument array' unless command.is_a?(Array)

    system('timeout', '-k', '2', sec.to_s, 'nice', '-n', '10', *command,
           out: File::NULL, err: File::NULL)
  rescue
    logger.error "Timeout when #{timeout_message} after #{sec}s"
    false
  end

  # Export functions as module functions
  module_function :try_within
  module_function :system_try_within
end
