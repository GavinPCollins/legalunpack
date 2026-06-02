require "test_helper"

class PackagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "packages@example.com", password: "password")
  end

  test "should get index" do
    get packages_url
    assert_response :success
  end

  test "should get show" do
    get package_url(1)
    assert_response :success
  end

  test "should get new" do
    get new_package_url
    assert_response :success
  end

  test "should post create" do
    post packages_url
    assert_response :success
  end

  test "should get edit" do
    get edit_package_url(1)
    assert_response :success
  end

  test "should patch update" do
    patch package_url(1)
    assert_response :success
  end

  test "should delete destroy" do
    delete package_url(1)
    assert_response :success
  end
end
