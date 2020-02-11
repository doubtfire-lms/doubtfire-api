# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class ActivityTypeSerializer < DoubtfireSerializer
  attributes :id, :name, :abbreviation
end
