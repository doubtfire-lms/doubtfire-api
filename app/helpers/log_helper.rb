#
# A universal logger
#
module LogHelper
  def logger
    Grape::API.logger
  end
end
