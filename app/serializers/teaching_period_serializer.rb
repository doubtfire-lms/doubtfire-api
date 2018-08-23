class TeachingPeriodSerializer < ActiveModel::Serializer
  attributes :id, :period, :year, :start_date, :end_date
end
