class Badge < ActiveRecord::Base
  belongs_to :sub_task_definitions

  attr_accessible :description, :large_image_url, :name, :references, :small_image_url
end
