# frozen_string_literal: true

class AllowedCharactersValidator < ActiveModel::EachValidator
  ALPHANUMERIC_CHARACTER = /\A[\p{L}\p{M}\p{N}]\z/u
  CHARACTER_WHITELISTS = {
    first_name: " -()_/,.'’",
    last_name: " -()_/,.'’",
    preferred_name: " -()_/,.'’",
    unit_name: " -#()",
    title: " -#()&/:_.'\"",
    unit_code: "-#/_"
  }.freeze

  def validate_each(record, attribute, value)
    return if value.blank?

    whitelist = CHARACTER_WHITELISTS.fetch(options.fetch(:type))
    return if value.each_char.all? { |character| alphanumeric?(character) || whitelist.include?(character) }

    record.errors.add(attribute, 'contains unsupported characters')
  end

  private

  def alphanumeric?(character)
    character.match?(ALPHANUMERIC_CHARACTER)
  end
end
