require 'terminator'
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
  def try_within(sec, timeout_message = "operation", &block)
    Terminator.terminate sec do
      block.call rescue logger.error "Timeout when #{timeout_message} after #{sec}s"
    end
  end

  # Export functions as module functions
  module_function :try_within
end
