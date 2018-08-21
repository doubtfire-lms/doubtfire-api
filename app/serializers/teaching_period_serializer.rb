class TeachingPeriodSerializer < ActiveModel::Serializer
  attributes :id, :period, :year

  def period
    object.period
  end

  def year
    object.year
  end
end
