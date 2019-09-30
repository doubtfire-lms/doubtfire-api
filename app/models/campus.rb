class Campus < ActiveRecord::Base
  enum mode: { physical: 0, online: 1 }
end
