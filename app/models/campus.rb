class Campus < ActiveRecord::Base
  # Relationships
  has_many    :tutorials, dependent: :delete_all
  has_many    :projects,  dependent: :delete_all

  validates :name, presence: true
  validates :mode, presence: true

  enum mode: { physical: 0, online: 1 }
end
