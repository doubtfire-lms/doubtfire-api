module Entities
  class UnitContentSiteEntity < Grape::Entity
    expose :id
    expose :unit_id
    expose :name
    expose :original_filename
    expose :root_dir
    expose :root_dir_options
    expose :is_main
    expose :created_at
    expose :updated_at
  end
end
