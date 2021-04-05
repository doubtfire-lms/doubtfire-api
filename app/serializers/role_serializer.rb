# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class RoleSerializer < DoubtfireSerializer
  attributes :name, :description
end
