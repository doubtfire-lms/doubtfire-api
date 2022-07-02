module Entities
  class TeachingPeriodEntity < Grape::Entity
    expose :id
    expose :period
    expose :year
    expose :start_date
    expose :end_date
    expose :active_until
    expose :active do |teaching_period, options|
      object.active_until > DateTime.now
    end
    expose :breaks, if: :full_details, using: Entities::BreakEntity
    expose :units, if: :full_details do |teaching_period, options|
      Entities::UnitEntity.represent teaching_period.units, summary_only: true, user: options[:user]
    end
  end
end
