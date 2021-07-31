class Room < ApplicationRecord
  has_many :check_ins
  has_many :tutorials

  def checkout_all(except_tutorial, time_limit)
    # TODO
  end
end
