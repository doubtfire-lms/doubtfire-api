class DoubtfireSerializer < ActiveModel::Serializer
  def object
    result = super()
    return result unless result.is_a? ActiveModel::Serializer
    result.object
  end
end