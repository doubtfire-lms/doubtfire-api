require 'grape'
module Courseflow
  class CourseApi < Grape::API

    format :json
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get all course data"
    get '/course' do
      courses = Course.all # get all courses in the database
      present courses, with: Entities::CourseEntity # present the courses using the CourseEntity
    end

    desc "Get course by ID"
    params do
      requires :courseId, type: Integer, desc: "Course ID"
    end
    get '/course/courseId/:courseId' do
      course = Course.find(params[:courseId]) # find the course by ID
      present course, with: Entities::CourseEntity      # present the course using the CourseEntity
    end

    desc "Get courses that partially match the search params"
    params do # define the parameters that can be used to filter the courses, all optional, if none given it'll return every course
      optional :name, type: String, desc: "Course name"
      optional :code, type: String, desc: "Course code"
      optional :year, type: Integer, desc: "Course year"
    end
    get '/course/search' do
      courses = Course.all # gets all courses initially

      courses = courses.where("name LIKE :name", name: "%#{params[:name]}%") if params[:name].present?  # if name is provided, filter by name, even partially
      courses = courses.where("code LIKE :code", code: "%#{params[:code]}%") if params[:code].present?  # if code is provided, filter by code, (can do things like SIT to get all SIT courses)
      courses = courses.where(year: params[:year]) if params[:year].present?                  # if year is provided, filter by year

      present courses, with: Entities::CourseEntity                                                     # return the filtered courses
    end

    desc "Add a new course"
    params do # define the parameters required to create a new course
      requires :name, type: String
      requires :code, type: String
      requires :year, type: Integer
      requires :version, type: String
      requires :url, type: String
    end
    post '/course' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to create a course' }, 403)
      end
      course = Course.new(params) # create a new course with the provided params
      if course.save
        present course, with: Entities::CourseEntity # if the course is saved, present the course using the CourseEntity
      else
        error!({ error: "Failed to create course", details: course.errors.full_messages }, 400) # if the course is not saved, return an error with the full error messages
      end
    end

    desc "Update an existing course via its ID"
    params do # define the parameters required to update a course
      requires :courseId, type: Integer, desc: "Course ID"
      requires :name, type: String
      requires :code, type: String
      requires :year, type: Integer
      requires :version, type: String
      requires :url, type: String
    end
    put '/course/courseId/:courseId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to update a course' }, 403)
      end
      course = Course.find(params[:courseId]) # find the course by ID
      error!({ error: "Course not found" }, 404) unless course # return an error if the course is not found

      if course.update(name: params[:name], code: params[:code], year: params[:year], version: params[:version], url: params[:url]) # update the course with the provided params
        present course, with: Entities::CourseEntity # if the course is updated, present the course using the CourseEntity
      else
        error!({ error: "Failed to update course", details: course.errors.full_messages }, 400) # if the course is not updated, return an error with the full error messages
      end
    end

    desc "Deletes an existing course via its ID"
    params do
      requires :courseId, type: Integer, desc: "Course ID"
    end
    delete '/course/courseId/:courseId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to delete a course' }, 403)
      end
      course = Course.find(params[:courseId]) # find the course by ID
      course.destroy
      { message: "Course with ID #{params[:courseId]} has been deleted" } # return a message saying the course was deleted
    end
  end
end
