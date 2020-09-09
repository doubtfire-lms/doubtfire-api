class WebcalSerializer < ActiveModel::Serializer
  attributes :id, :guid, :include_start_dates, :unit_exclusions

  def unit_exclusions
    object.webcal_unit_exclusions.map(&:unit_id)
  end
end
