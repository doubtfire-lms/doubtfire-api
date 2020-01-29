# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class TeachingPeriodSerializer < ActiveModel::Serializer
  attributes :id, :period, :year, :start_date, :end_date, :active_until, :active, :breaks, :units

  def active
    object.active_until > DateTime.now
  end
end
