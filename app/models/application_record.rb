class ApplicationRecord < ActiveRecord::Base
  include LogHelper
  self.abstract_class = true
end
