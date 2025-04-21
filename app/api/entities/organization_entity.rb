module Entities
    class OrganizationEntity < Grape::Entity
      expose :id
      expose :name
      expose :description
      expose :email
      expose :is_enabled
      expose :created_at
      expose :updated_at

      expose :users, using: Entities::UserEntity, if: { includes: :users }
    end
  end