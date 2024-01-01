#
# Adds a logger function to make it easier to log
# using the standard logger.
#
module LogHelper
  #
  # Logger function returns the singleton logger
  #
  def logger
    Rails.logger
  end

  # Export functions as module functions
  module_function :logger
end
