module Entities
  class WebcalEntity < Grape::Entity
    expose :id, expose_nil: false
    expose :guid, expose_nil: false
    expose :include_start_dates, expose_nil: false

    expose :enabled do |webcal, options|
      webcal.present?
    end

    expose :reminder, expose_nil: false do |webcal, options|
      if webcal.nil? || webcal.reminder_time.nil? || webcal.reminder_unit.nil?
        nil
      else
        {
          time: webcal.reminder_time,
          unit: webcal.reminder_unit
        }
      end
    end

    expose :unit_exclusions do |webcal, options|
      webcal.webcal_unit_exclusions.map(&:unit_id)
    end
  end
end
