module Base64Helper
  def base64?(value)
    value.is_a?(String) && Base64.strict_encode64(Base64.decode64(value)) == value
  rescue ArgumentError
    false
  end
end
