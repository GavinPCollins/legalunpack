require "test_helper"

class UserRegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "creates user with email and username" do
    assert_difference("User.count", 1) do
      post user_registration_url, params: {
        user: {
          name: "Comparison User",
          username: "comparison",
          email: "comparison@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    user = User.find_by!(username: "comparison")
    assert_equal "comparison@example.com", user.email
    assert_not user.admin?
  end
end
