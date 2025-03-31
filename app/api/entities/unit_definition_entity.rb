
  module Entities
    class UnitDefinitionEntity < Grape::Entity
      expose :id
      expose :name
      expose :description
      expose :code
      expose :version
    end
  end
