require 'entities/moodle_group_mapping_entity'

module Entities
  class MoodleIntegrationEntity < Grape::Entity
    expose :id
    expose :course_id
    expose :assignment_id
    expose :assignment_name
    expose :fetch_extensions
    expose :group_mapping_enabled
    expose :moodle_group_mappings,
           as: :group_mappings,
           using: Entities::MoodleGroupMappingEntity
    expose :api_key_configured do |integration|
      integration.api_key.present?
    end
  end
end
