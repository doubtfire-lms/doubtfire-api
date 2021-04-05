# Serialise a hash using a list of attributes from the active model serialiser
class HashSerializer < DoubtfireSerializer
  # Add support for reading the attribute from the hash without Active Model support
  def read_attribute_for_serialization(attr)
    return object[attr] if object.key?(attr)
    return object[attr.to_sym] if object.key?(attr.to_sym)
    object[attr.to_s]
  end
end
