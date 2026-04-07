require 'grape'

class PerformanceBandsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  format :json

  before do
    authenticated?
  end

  resource :performance_bands do
    desc 'Get performance bands for a unit'

    params do
      requires :unit_id, type: Integer, desc: 'Unit ID'

      optional :high_threshold, type: Integer, default: 80,
               desc: 'Minimum grade for high band'

      optional :medium_threshold, type: Integer, default: 50,
               desc: 'Minimum grade for medium band'
    end

    get do
      unit = Unit.find_by(id: params[:unit_id])

      error!({ error: "Unit not found" }, 404) unless unit

      unless authorise?(current_user, unit, :view_performance_bands)
        error!({ error: "Unauthorized access to Unit #{params[:unit_id]}" }, 403)
      end

      students = unit.student_query(true)

      # Guard: ensure grade exists
      students = students.select { |s| !s.grade.nil? }

      high_threshold = params[:high_threshold]
      medium_threshold = params[:medium_threshold]

      bands = {
        high: [],
        medium: [],
        low: []
      }

      students.each do |student|
        grade = student.grade.to_f

        if grade >= high_threshold
          bands[:high] << student
        elsif grade >= medium_threshold
          bands[:medium] << student
        else
          bands[:low] << student
        end
      end

      {
        unit_id: unit.id,
        thresholds: {
          high: high_threshold,
          medium: medium_threshold
        },
        counts: {
          high: bands[:high].size,
          medium: bands[:medium].size,
          low: bands[:low].size
        },
        bands: bands.transform_values do |group|
          group.map do |s|
            {
              id: s.id,
              name: s.respond_to?(:name) ? s.name : nil,
              grade: s.grade
            }
          end
        end
      }
    end
  end
end