require 'grape'
require 'project_serializer'

module Api
  class SettingsApi < Grape::API

    #
    # Returns the current auth method
    #
    desc 'Return configurable details for the Doubtfire front end'
    get '/settings' do
      {
        externalName: Doubtfire::Application.config.institution[:product_name],
        overseer_enabled: ENV['OVERSEER_ENABLED'].present? && ENV['OVERSEER_ENABLED'].to_s.downcase == "true" ? true : false
      }
    end

    # Returns the current units with teaching periods
    # Return:
    # Unit Name, unit ID, teaching period name, year
    #
    desc 'Return all the units teaching period information'
    get '/teaching_periods/id/units' do
      units_with_teaching_periods = Unit.where('teaching_period_id is not NULL').select([:id, :name, :code, :teaching_period_id])
      result = units_with_teaching_periods.map do |unit|
        {
          unit_id: unit.id,
          unit_code: unit.code,
          period_name: TeachingPeriod.find(unit.teaching_period_id).period
        }
      end
      result
    end

    desc 'Return privacy policy details'
    get '/settings/privacy' do
      {
        privacy:    Doubtfire::Application.config.institution[:privacy],
        plagiarism: Doubtfire::Application.config.institution[:plagiarism]
      }
    end
  end
end
