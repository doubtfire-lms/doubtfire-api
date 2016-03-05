#
# A universal logger
#
module LogHelper
  def logger
    # Grape::API.logger
    Rails.logger
  end
  
  # Export functions as module functions
  module_function :logger
end
