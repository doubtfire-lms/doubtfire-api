require 'mongo'
class CountIncrementController < ApplicationController
    def index
        client = Mongo::Client.new('mongodb://127.0.0.1:27017/test')

            collection = client[:people]

            doc = { name: 'Steve', hobbies: [ 'hiking', 'tennis', 'fly fishing' ] }

            result = collection.insert_one(doc)
            result.n
            render json: result, status: 200
    end
end

