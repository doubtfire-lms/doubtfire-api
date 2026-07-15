module Entities
  class UnitContentSiteEntity < Grape::Entity
    expose :id
    expose :unit_id
    expose :name
    expose :original_filename
    expose :root_dir
    expose :root_dir_options
    expose :file_paths, if: ->(_site, options) { options[:include_file_paths] }
    expose :is_main
    expose :created_at
    expose :updated_at
  end
end
