#
# A universal logger
#
module LogHelper
  #
  # Logger function returns the singleton logger
  #
  def logger
    Doubtfire::Application.config.logger
  end

  # Export functions as module functions
  module_function :logger
end
