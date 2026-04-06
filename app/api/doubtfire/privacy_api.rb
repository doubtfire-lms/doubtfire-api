require 'grape'

class PrivacyApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  resource :privacy do
    desc 'Get anonymised student list'
    params do
      requires :unit_id, type: Integer, desc: 'Unit ID'
      optional :anonymised, type: Boolean, desc: 'Force anonymisation'
    end
    get '/students' do
      unit = Unit.find(params[:unit_id])

      # Authorisation check
      if authorise?(current_user, unit, :get_students) || authorise?(current_user, User, :admin_units)
        students = unit.student_query(true)

        if params[:anonymised] || !current_user.tutor?
          # Apply anonymisation
          students.map do |s|
            {
              id: s.id,
              display_name: "Student ##{s.id}",
              username: "anon_#{s.id}",
              progress: s.progress
            }
          end
        else
          # Full data for tutors/admins
          students
        end
      else
        error!({ error: "Unauthorized access to Unit #{params[:unit_id]}" }, 403)
      end
    end
  end
end