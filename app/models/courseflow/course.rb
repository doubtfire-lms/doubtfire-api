module Courseflow
  class Course < ApplicationRecord
    # Validation rules for attributes in the course model
    validates :name, presence: true, length: {maximum: 250}
    validates :code, presence: true, uniqueness: true, length: {maximum: 10} # assuming that there is only one entry for each code, not sure if this is the case
    validates :year, presence: true
    validates :version, presence: true
    validates :url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp}
  end
end
