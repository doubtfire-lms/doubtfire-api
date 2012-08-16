# This form is implemented as a Model object so we can take advantage of the form validation features.
# For details, see RailsCasts #219
class ConvenorContactForm
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :project_template, :role

  validates_presence_of :project_template, :role

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end
  
  def persisted?
    false
  end

end