# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class GroupSetSerializer < ActiveModel::Serializer
  attributes :id, :name,
             :allow_students_to_create_groups,
             :allow_students_to_manage_groups,
             :keep_groups_in_same_class,
             :capacity
end
