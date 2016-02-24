#
# A universal logger
#
module LogHelper
  def self.logger
    Grape::API.logger
  end
  def logger
    self.logger
  end
end
