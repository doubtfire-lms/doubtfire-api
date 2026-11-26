require 'entities/unit_content_site_entity'

module Entities
  class UnitContentLinkEntity < Grape::Entity
    expose :id
    expose :unit_id
    expose :unit_content_site_id
    expose :context_type
    expose :context_key
    expose :route
    expose :unit_content_site, as: :site, using: Entities::UnitContentSiteEntity
  end
end
