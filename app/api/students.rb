require 'grape'
require 'project_serializer'

module Api
  class Students < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get users"
    params do
      requires :unit_id, type: Integer, desc: 'The unit to get the students for'
      optional :all, type: Boolean, desc: 'Show all students or just current students'
    end
    get '/students' do
      unit = Unit.find(params[:unit_id])

      if (authorise? current_user, unit, :get_students) || (authorise? current_user, User, :admin_units)
        result = unit.students

        if params[:all].nil? or ((not params[:all].nil?) and not params[:all])
          result = result.where('enrolled = true')
        end

        ActiveModel::ArraySerializer.new(result, each_serializer: StudentProjectSerializer)
      else
        error!({"error" => "Couldn't find Unit with id=#{params[:unit_id]}" }, 403)
      end
    end
  end
end
