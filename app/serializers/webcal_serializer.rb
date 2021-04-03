class WebcalSerializer < ActiveModel::Serializer
  attributes :id, :guid, :include_start_dates, :reminder, :unit_exclusions

  def reminder
    if object.reminder_time.nil? || object.reminder_unit.nil?
      nil
    else
      {
        time: object.reminder_time,
        unit: object.reminder_unit
      }
    end
  end

  def unit_exclusions
    object.webcal_unit_exclusions.map(&:unit_id)
  end
end
