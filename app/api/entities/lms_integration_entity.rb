require 'entities/lms_group_mapping_entity'

module Entities
  class LmsIntegrationEntity < Grape::Entity
    expose :id
    expose :source
    expose :assignment_id
    expose :assignment_name
    expose :fetch_extensions
    expose :auto_sync_students
    expose :withdraw_missing_students
    expose :auto_sync_extensions
    expose :group_mapping_enabled
    expose :skip_ungraded
    expose :send_grade_rationale
    expose :validated
    expose :validated_at
    expose :auto_sync_failing_since
    expose :auto_sync_last_error
    expose :auto_sync_turn_off_date
    expose :lms_group_mappings,
           as: :group_mappings,
           using: Entities::LmsGroupMappingEntity
  end
end
