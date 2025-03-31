require 'grape'
module Courseflow
  class CourseMapUnitApi < Grape::API

    format :json
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get course map unit via course map ID"
    params do
      requires :courseMapId, type: Integer, desc: "Course map ID"
    end
    get '/coursemapunit/courseMapId/:courseMapId' do
      course_map_units = CourseMapUnit.where(courseMapId: params[:courseMapId]) # get all course map units associated with the course map ID
      present course_map_units, with: Entities::CourseMapUnitEntity # present the course map units using the CourseMapUnitEntity
    end

    desc "Add a new course map unit"
    params do
      requires :courseMapId, type: Integer
      requires :unitId, type: Integer
      requires :yearSlot, type: Integer
      requires :teachingPeriodSlot, type: Integer
      requires :unitSlot, type: Integer
    end
    post '/coursemapunit' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to add new course map unit' }, 403)
      end
      course_map_unit = CourseMapUnit.new(params) # create a new course map unit with the provided params
      if course_map_unit.save
        present course_map_unit, with: Entities::CourseMapUnitEntity # if the course map unit is saved, present the course map unit using the CourseMapUnitEntity
      else
        error!({ error: "Failed to create course map unit", details: course_map_unit.errors.full_messages }, 400) # if the course map unit is not saved, return an error with the full error messages
      end
    end

    desc "Update an existing course map unit via its ID"
    params do
      requires :courseMapUnitId, type: Integer, desc: "Course map unit ID"
      requires :courseMapId, type: Integer
      requires :unitId, type: Integer
      requires :yearSlot, type: Integer
      requires :teachingPeriodSlot, type: Integer
      requires :unitSlot, type: Integer
    end
    put '/coursemapunit/courseMapUnitId/:courseMapUnitId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to update a course map unit' }, 403)
      end
      course_map_unit = CourseMapUnit.find(params[:courseMapUnitId])
      error!({ error: "Course map unit not found" }, 404) unless course_map_unit

      if course_map_unit.update(courseMapId: params[:courseMapId], unitId: params[:unitId], yearSlot: params[:yearSlot], teachingPeriodSlot: params[:teachingPeriodSlot], unitSlot: params[:unitSlot])
        present course_map_unit, with: Entities::CourseMapUnitEntity
      else
        error!({ error: "Failed to update course map unit", details: course_map_unit.errors.full_messages }, 400)
      end
    end

    desc "Delete all course map units via its associated course map ID"
    params do
      requires :courseMapId, type: Integer, desc: "Course map ID"
    end
    delete '/coursemapunit/courseMapId/:courseMapId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to delete course map units' }, 403)
      end
      course_map_units = CourseMapUnit.where(courseMapId: params[:courseMapId]) # delete all course map units associated with the course map ID
      course_map_units.destroy_all
      { message: "Course map units with course map ID #{params[:courseMapId]} have been deleted" }
    end

    desc "Delete a course map unit via its ID"
    params do
      requires :courseMapUnitId, type: Integer, desc: "Course map unit ID"
    end
    delete '/coursemapunit/courseMapUnitId/:courseMapUnitId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to delete course map units' }, 403)
      end
      course_map_unit = CourseMapUnit.find(params[:courseMapUnitId]) # delete the course map unit by ID
      course_map_unit.destroy
      { message: "Course map unit with ID #{params[:courseMapUnitId]} has been deleted" } # return a message saying the course map unit was deleted
    end
  end
end
