require "test_helper"

class ChatbotSessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "chatflow@example.com", password: "password", username: "chatflow")
    @package = @user.packages.create!(name: "Lease review")
    sign_in @user
  end

  test "returns answer for package-wide question when extraction present" do
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "The lease term is 12 months and rents are due monthly.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    # Temporarily replace AiClient.call for deterministic test
    class << AiClient
      if method_defined?(:call)
        alias_method :__orig_call_for_test, :call
      end

      define_method(:call) do |_input|
        "The lease term is 12 months."
      end
    end

    assert_difference("ChatMessage.count", 2) do
      post package_chatbot_sessions_url(@package), params: { question: "What is the lease term?", target: "package" }, as: :json
    end

    # Restore original AiClient.call
    class << AiClient
      remove_method :call
      if method_defined?(:__orig_call_for_test)
        alias_method :call, :__orig_call_for_test
        remove_method :__orig_call_for_test
      end
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "The lease term is 12 months.", json["answer"]
    roles = @package.chat_messages.order(:created_at).pluck(:role)
    assert_equal ["user", "assistant"], roles
  end

  test "returns not_found for another user's package" do
    other = User.create!(email: "other@example.com", password: "password", username: "other")
    other_package = other.packages.create!(name: "Private")

    assert_no_difference("ChatMessage.count") do
      post package_chatbot_sessions_url(other_package), params: { question: "hi" }, as: :json
      assert_response :not_found
    end
  end
end
