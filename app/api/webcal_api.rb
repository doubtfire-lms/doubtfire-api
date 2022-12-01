require 'grape'
require 'icalendar'

class WebcalApi < Grape::API
  helpers AuthenticationHelpers

  helpers do
    #
    # Wraps the specified value (expected to be either `nil` or a `Webcal`) in a hash `{ enabled: true | false }` used
    # to prevent the API returning `null`.
    #
    def present_webcal(webcal)
      if webcal.present?
        present webcal, with: Entities::WebcalEntity
      else
        response = { enabled: false }
        present response, with: Grape::Presenters::Presenter
      end
    end
  end

  before do
    authenticated?
  end

  desc 'Get webcal details of the authenticated user'
  get '/webcal' do
    present_webcal current_user.webcal
  end

  desc 'Update webcal details of the authenticated user'
  params do
    requires :webcal, type: Hash do
      optional :enabled,             type: Boolean,                                 desc: 'Is the webcal enabled?'
      optional :should_change_guid,  type: Boolean,                                 desc: 'Should the GUID of the webcal be changed?'
      optional :include_start_dates, type: Boolean,                                 desc: 'Should events for start dates be included?'
      optional :unit_exclusions,     type: Array[Integer],                          desc: 'IDs of units that must be excluded from the webcal'

      # `all_or_none_of` is used here instead of 2 `requires` parameters to allow `reminder` to be set to `null`.
      optional :reminder,            type: Hash do
        optional :time,              type: Integer
        optional :unit,              type: String, values: Webcal.valid_time_units, desc: 'w: weeks, d: days, h: hours, m: minutes'
        all_or_none_of :time, :unit
      end
    end
  end
  put '/webcal' do
    webcal_params = params[:webcal]

    user = current_user

    cal = Webcal
          .includes(:webcal_unit_exclusions)
          .where(user_id: user.id)
          .load
          .first

    # Create or destroy the user's webcal, according to the `enabled` parameter.
    if webcal_params.key?(:enabled)
      if webcal_params[:enabled] and cal.nil?
        cal = user.create_webcal(guid: SecureRandom.uuid)
      elsif !webcal_params[:enabled] and cal.present?
        cal.destroy
      end
    end

    if cal.nil? || cal.destroyed?
      present_webcal nil
      return
    end

    webcal_update_params = {}

    # Change the GUID if requested.
    if webcal_params.key?(:should_change_guid)
      webcal_update_params[:guid] = SecureRandom.uuid
    end

    # Change the reminder if requested.
    if webcal_params.key?(:reminder)
      if webcal_params[:reminder].nil?
        webcal_update_params[:reminder_time] = webcal_update_params[:reminder_unit] = nil
      else
        webcal_update_params[:reminder_time] = webcal_params[:reminder][:time]
        webcal_update_params[:reminder_unit] = webcal_params[:reminder][:unit]
      end
    end

    # Set any other properties that have to be updated verbatim.
    webcal_update_params.merge! ActionController::Parameters.new(webcal_params).permit(
      :include_start_dates,
      :reminder_time,
      :reminder_unit
    )

    # Update calendar.
    cal.update! webcal_update_params

    # Update unit exclusions, if specified.
    if webcal_params.key?(:unit_exclusions)

      # Delete existing exclusions.
      cal.webcal_unit_exclusions.destroy_all

      # Add exclusions with valid unit IDs.
      if webcal_params[:unit_exclusions].any?
        cal.webcal_unit_exclusions.create(
          Unit
            .joins(:projects)
            .where(
              projects: { user_id: user.id },
              units: { id: webcal_params[:unit_exclusions], active: true }
            )
            .pluck(:id)
            .map { |i| { unit_id: i } }
        )
      end
    end

    present_webcal cal
  end
end
