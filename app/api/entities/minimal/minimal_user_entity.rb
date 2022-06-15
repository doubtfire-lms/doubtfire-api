
module Entities::Minimal
  class MinimalUserEntity < Grape::Entity
    expose :id
    expose :email
    expose :first_name
    expose :last_name
    expose :username
    expose :nickname
  end
end
