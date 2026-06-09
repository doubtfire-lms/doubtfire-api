require 'test_helper'

class OverseerImageApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::OverseerTestHelper

  def app
    Rails.application
  end

  def setup
    setup_overseer_enabled
  end

  def test_get_all_overseer_images
    FactoryBot.create_list(:overseer_image, 5)
    expected_data = OverseerImage.all

    admin = FactoryBot.create(:user, :admin)
    add_auth_header_for(user: admin)

    get '/api/admin/overseer_images'

    assert_equal 200, last_response.status
    assert_equal expected_data.count, last_response_body.count, last_response_body

    response_keys = %w[name tag pulled_image_text pulled_image_status]

    last_response_body.each do |data|
      expected_data = OverseerImage.find(data['id'])
      assert_json_matches_model(expected_data, data, response_keys)
    end
  end

  def test_get_all_overseer_images_for_convenor
    FactoryBot.create_list(:overseer_image, 5)
    expected_data = OverseerImage.all
    convenor = FactoryBot.create(:user, :convenor)
    add_auth_header_for(user: convenor)

    get '/api/admin/overseer_images'

    assert_equal 200, last_response.status
    assert_equal expected_data.count, last_response_body.count, last_response_body
  end

  def test_no_get_for_students_or_tutors
    FactoryBot.create_list(:overseer_image, 5)
    expected_data = OverseerImage.all

    student = FactoryBot.create(:user, :student)
    add_auth_header_for(user: student)

    get '/api/admin/overseer_images'

    assert_equal 403, last_response.status

    tutor = FactoryBot.create(:user, :tutor)
    add_auth_header_for(user: tutor)

    get '/api/admin/overseer_images'

    assert_equal 403, last_response.status
  end

  def test_get_single_overseer_image
    overseer_image = FactoryBot.create(:overseer_image)

    admin = FactoryBot.create(:user, :admin)
    add_auth_header_for(user: admin)

    get "/api/admin/overseer_images/#{overseer_image.id}"

    assert_equal 200, last_response.status

    response_keys = %w[name tag pulled_image_text pulled_image_status last_pulled_date]
    assert_json_matches_model(overseer_image, last_response_body, response_keys)
  end

  def test_get_single_overseer_image_for_convenor
    overseer_image = FactoryBot.create(:overseer_image)

    convenor = FactoryBot.create(:user, :convenor)
    add_auth_header_for(user: convenor)

    get "/api/admin/overseer_images/#{overseer_image.id}"

    assert_equal 200, last_response.status

    response_keys = %w[name tag pulled_image_text pulled_image_status last_pulled_date]
    assert_json_matches_model(overseer_image, last_response_body, response_keys)
  end

  def test_no_get_single_overseer_image_for_students_or_tutors
    overseer_image = FactoryBot.create(:overseer_image)

    student = FactoryBot.create(:user, :student)
    add_auth_header_for(user: student)

    get "/api/admin/overseer_images/#{overseer_image.id}"

    assert_equal 403, last_response.status

    tutor = FactoryBot.create(:user, :tutor)

    add_auth_header_for(user: tutor)

    get "/api/admin/overseer_images/#{overseer_image.id}"

    assert_equal 403, last_response.status
  end

  # POST tests
  # 1: Admin can create a new overseer image
  def test_admin_can_post_overseer_image
    # Admin user
    admin = FactoryBot.create(:user, :admin)

    # the number of images before post
    no_images = OverseerImage.count

    # the data that we want to post/create
    data_to_post = {
      overseer_image: FactoryBot.build(:overseer_image)
    }

    # auth_token and username added to header
    add_auth_header_for(user: admin)

    # perform the POST
    post_json '/api/admin/overseer_images', data_to_post

    # check if the request get through
    assert_equal 201, last_response.status, "Failed to add image: #{data_to_post}"

    # check if the details posted match as expected
    response_keys = %w[name tag pulled_image_text pulled_image_status last_pulled_date]
    overseer_image = OverseerImage.find(last_response_body['id'])
    assert_json_matches_model(overseer_image, last_response_body, response_keys)

    assert_nil overseer_image.pulled_image_text
    assert_nil overseer_image.pulled_image_status

    # check if the details in the newly created match as pre-set data
    assert_equal data_to_post[:overseer_image]['name'], overseer_image.name
    assert_equal data_to_post[:overseer_image]['tag'], overseer_image.tag

    # check if one more image is created
    assert_equal no_images + 1, OverseerImage.count
  end

  # 2: Convenor cannot create a new overseer image
  def test_convenor_and_student_cannot_post_overseer_image
    # Convenor user
    convenor = FactoryBot.create(:user, :convenor)
    student = FactoryBot.create(:user, :student)

    # the number of teaching period before post
    overseer_image_type = OverseerImage.count

    # the data that we want to post/create
    data_to_post = {
      overseer_image: FactoryBot.build(:overseer_image)
    }

    # auth_token and username added to header
    add_auth_header_for(user: convenor)

    # perform the POST
    post_json '/api/admin/overseer_images', data_to_post

    # check if the request get through
    assert_equal 403, last_response.status

    # auth_token and username added to header
    add_auth_header_for(user: student)

    # perform the POST
    post_json '/api/admin/overseer_images', data_to_post

    # check if the request get through
    assert_equal 403, last_response.status

    # check if no more images is created
    assert_equal overseer_image_type, OverseerImage.count
  end

  # PUT tests
  # 1: Admin can replace an image
  def test_admin_can_put_overseer_image
    # Admin user
    admin = FactoryBot.create(:user, :admin)

    # The overseer image to be replaced
    overseer_image = FactoryBot.create(:overseer_image)

    # Data to replace
    data_to_put = {
      overseer_image: FactoryBot.build(:overseer_image)
    }

    # auth_token and username added to header
    add_auth_header_for(user: admin)

    # Update overseer_image with data_to_put
    put_json "/api/admin/overseer_images/#{overseer_image.id}", data_to_put

    # check if the request get through
    assert_equal 200, last_response.status, "Failed to update image: #{data_to_put} for #{overseer_image.inspect}"

    # check if the details posted match as expected
    response_keys = %w[name tag pulled_image_text pulled_image_status last_pulled_date]
    overseer_image_updated = overseer_image.reload
    assert_json_matches_model(overseer_image_updated, last_response_body, response_keys)

    # check if the details in the replaced teaching period match as data set to replace
    assert_equal data_to_put[:overseer_image]['name'], overseer_image_updated.name
    assert_equal data_to_put[:overseer_image]['tag'], overseer_image_updated.tag

    # Check other attributes are cleared
    assert_nil overseer_image_updated.pulled_image_text
    assert_nil overseer_image_updated.pulled_image_status
  end

  # 2: Convenor cannot replace an overseer image
  def test_non_admin_cannot_put_overseer_images
    # Convenor user
    convenor = FactoryBot.create(:user, :convenor)
    tutor = FactoryBot.create(:user, :tutor)
    student = FactoryBot.create(:user, :student)
    auditor = FactoryBot.create(:user, :auditor)

    users_to_test = [convenor, tutor, student, auditor]

    # The overseer image to be replaced
    overseer_image = FactoryBot.create(:overseer_image)

    # Data to replace
    data_to_put = {
      overseer_image: FactoryBot.build(:overseer_image)
    }

    users_to_test.each do |user|
      # auth_token and username added to header
      add_auth_header_for(user: user)

      # Update overseer_image with data_to_put
      put_json "/api/admin/overseer_images/#{overseer_image.id}", data_to_put

      # check if the request get through
      assert_equal 403, last_response.status, "User: #{user.role} updated overseer image"
    end
  end

  def test_delete_overseer_image
    # Create a overseer image
    overseer_image = FactoryBot.create(:overseer_image)

    # number of overseer image before delete
    number_of_images = OverseerImage.count

    # auth_token and username added to header
    admin = FactoryBot.create(:user, :admin)
    add_auth_header_for(user: admin)

    # perform the delete
    delete_json "/api/admin/overseer_images/#{overseer_image.id}"

    # Check if the delete get through
    assert_equal 200, last_response.status

    # Check delete if success
    assert_equal OverseerImage.count, number_of_images - 1

    # Check that you can't find the deleted id
    assert_not OverseerImage.exists?(overseer_image.id)
  end

  def test_non_admin_cannot_delete_overseer_image
    # A user with student role which does not have permision to delete a overseer image
    users = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor)
    ]

    # create a overseer image to delete
    overseer_image = FactoryBot.create (:overseer_image)

    # number of overseer image before delete
    number_of_images = OverseerImage.count

    users.each do |user|
      # auth_token and username added to header
      add_auth_header_for(user: user)

      # perform the delete
      delete_json "/api/admin/overseer_images/#{overseer_image.id}"

      # check if the delete does not get through
      assert_equal 403, last_response.status, "User: #{user.role} deleted overseer image"

      # check if the number of ativity_type is still the same
      assert_equal OverseerImage.count, number_of_images
    end

    # Check that you still can find the deleted id
    assert OverseerImage.exists?(overseer_image.id)
  end

  def test_delete_overseer_image_with_associated_units
    unit = FactoryBot.create(:unit, with_students: false)
    overseer_image = FactoryBot.create(:overseer_image, units: [unit])
    unit.update(overseer_image: overseer_image)

    # number of overseer image before delete
    number_of_images = OverseerImage.count

    # auth_token and username added to header
    admin = FactoryBot.create(:user, :admin)
    add_auth_header_for(user: admin)

    # perform the delete
    delete_json "/api/admin/overseer_images/#{overseer_image.id}"

    # Check if the delete get through
    assert_equal 403, last_response.status

    # Check delete if success
    assert_equal OverseerImage.count, number_of_images

    # Check that you can't find the deleted id
    assert OverseerImage.exists?(overseer_image.id)
  end

  def test_delete_overseer_image_with_associated_task_definitions
    unit = FactoryBot.create(:unit, with_students: false)
    overseer_image = FactoryBot.create(:overseer_image, units: [unit])
    unit.task_definitions.first.update(overseer_image: overseer_image)

    # number of overseer image before delete
    number_of_images = OverseerImage.count

    # auth_token and username added to header
    admin = FactoryBot.create(:user, :admin)
    add_auth_header_for(user: admin)

    # perform the delete
    delete_json "/api/admin/overseer_images/#{overseer_image.id}"

    # Check if the delete get through
    assert_equal 403, last_response.status

    # Check delete if success
    assert_equal OverseerImage.count, number_of_images

    # Check that you can't find the deleted id
    assert OverseerImage.exists?(overseer_image.id)
  end
end
