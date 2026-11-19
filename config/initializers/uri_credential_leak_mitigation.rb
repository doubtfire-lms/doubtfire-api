require 'uri'

# Mitigates credential leakage when combining a credential-bearing base URI
# with a relative URI via URI#+ by stripping userinfo from the merged result.
module UriCredentialLeakMitigation
  def +(other)
    combined = super

    return combined unless other.respond_to?(:absolute?) && !other.absolute?
    return combined unless combined.respond_to?(:user=) || combined.respond_to?(:password=)

    sanitized = combined.dup
    sanitized.user = nil if sanitized.respond_to?(:user=)
    sanitized.password = nil if sanitized.respond_to?(:password=)
    sanitized
  rescue URI::InvalidComponentError
    combined
  end
end

URI::Generic.prepend(UriCredentialLeakMitigation)
