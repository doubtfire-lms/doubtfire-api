require 'grape'

module Api

  class WebcalApi < Grape::API

    desc 'Serves web calendars ("webcals") that include the target/extension dates of all tasks of students\' active units.'
    params do
      requires :id, type: String, desc: 'The ID of the webcal'
    end
    get '/webcal/:id' do
      # Retrieve the specified webcal.
      webcal = Webcal.find(params[:id])
      task_definitions = []

      # Retrieve task definitions and tasks of the user's active units.
      # TODO: Can this be reduced to 1 query instead of 1 + # of projects?
      webcal.user.projects
        .joins(:unit)
        .where(units: { active: true })
        .each do |prj|
          prj.unit.task_definitions.includes(:tasks).where(tasks: { project_id: [prj.id, nil] }).each do |td|
            task_definitions.push(td)
          end
        end

      task_definitions
    end

  end
end
