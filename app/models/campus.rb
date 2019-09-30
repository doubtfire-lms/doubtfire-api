class Campus < ActiveRecord::Base
  validates :name, presence: true
  validates :mode, presence: true

  enum mode: { physical: 0, online: 1 }
end
