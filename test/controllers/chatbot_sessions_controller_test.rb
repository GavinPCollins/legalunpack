require "test_helper"

class ChatbotSessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "chatflow@example.com", password: "password", username: "chatflow")
    @package = @user.packages.create!(name: "Lease review")
    sign_in @user
  end

  test "returns chat history for the package" do
    user_message = @package.chat_messages.create!(
      user: @user,
      role: "user",
      content: "What is the lease term?",
      created_at: 2.minutes.ago
    )
    assistant_message = @package.chat_messages.create!(
      user: @user,
      role: "assistant",
      content: "The lease term is 12 months.",
      created_at: 1.minute.ago
    )

    get package_chatbot_sessions_url(@package), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["messages"].length
    assert_equal [ user_message.id, assistant_message.id ], json["messages"].map { |message| message["id"] }
    assert_equal [ "user", "assistant" ], json["messages"].map { |message| message["role"] }
    assert_equal "What is the lease term?", json.dig("messages", 0, "content")
    assert_equal user_message.created_at.iso8601, json.dig("messages", 0, "created_at")
  end

  test "limits chat history to the latest 50 messages by default" do
    51.times do |index|
      @package.chat_messages.create!(
        user: @user,
        role: index.even? ? "user" : "assistant",
        content: "Message #{index + 1}"
      )
    end

    get package_chatbot_sessions_url(@package), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 50, json["messages"].length
    assert_equal "Message 2", json.dig("messages", 0, "content")
    assert_equal "Message 51", json.dig("messages", 49, "content")
  end

  test "supports smaller chat history limits" do
    3.times do |index|
      @package.chat_messages.create!(
        user: @user,
        role: "user",
        content: "Message #{index + 1}"
      )
    end

    get package_chatbot_sessions_url(@package, limit: 2), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [ "Message 2", "Message 3" ], json["messages"].map { |message| message["content"] }
  end

  test "caps requested chat history limit at 50" do
    51.times do |index|
      @package.chat_messages.create!(
        user: @user,
        role: "user",
        content: "Message #{index + 1}"
      )
    end

    get package_chatbot_sessions_url(@package, limit: 100), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 50, json["messages"].length
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
    assert_nil json["external_analysis"]
    assert_nil json["external_confidence"]
    assert_equal "What is the lease term?", json.dig("user_message", "content")
    assert_equal "user", json.dig("user_message", "role")
    assert_equal "The lease term is 12 months.", json.dig("assistant_message", "content")
    assert_equal "assistant", json.dig("assistant_message", "role")
    assert_not_nil json.dig("user_message", "id")
    assert_not_nil json.dig("assistant_message", "id")
    assert_not_nil json.dig("user_message", "created_at")
    assert_not_nil json.dig("assistant_message", "created_at")
    roles = @package.chat_messages.order(:created_at).pluck(:role)
    assert_equal ["user", "assistant"], roles
  end

  test "saves and returns legal references for assistant responses" do
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "The agreement discusses refunds for goods with major problems.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    source = LegalSource.create!(
      title: "Refunds and returns",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      publisher: "Consumer Affairs Victoria",
      source_url: "https://www.consumer.vic.gov.au/refunds",
      source_format: "html"
    )
    chunk = source.legal_source_chunks.create!(
      heading: "Major problems",
      content: "Consumers may be entitled to a refund when goods have a major problem.",
      position: 1
    )

    captured_prompt = nil
    original_ai_call = AiClient.method(:call)
    original_retriever_call = LegalReferenceRetriever.method(:call)
    LegalReferenceRetriever.define_singleton_method(:call) do |query:, **_options|
      [ LegalReferenceRetriever::Result.new(number: 1, chunk: chunk) ]
    end
    AiClient.define_singleton_method(:call) do |prompt|
      captured_prompt = prompt
      "The refund term should be reviewed against [L1]."
    end

    assert_difference("ChatMessageLegalReference.count", 1) do
      post package_chatbot_sessions_url(@package),
           params: { question: "Does this handle refund major problems?", target: "package" },
           as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes captured_prompt, "[L1] Refunds and returns | Major problems"
    assert_equal "L1", json.dig("legal_references", 0, "label")
    assert_equal "Refunds and returns", json.dig("legal_references", 0, "title")
    assert_equal "Major problems", json.dig("legal_references", 0, "heading")
    assert_equal "Consumer Affairs Victoria", json.dig("legal_references", 0, "publisher")
    assert_includes json.dig("legal_references", 0, "content"), "major problem"
    assert_equal json["legal_references"], json.dig("assistant_message", "legal_references")
  ensure
    AiClient.define_singleton_method(:call, original_ai_call) if original_ai_call
    LegalReferenceRetriever.define_singleton_method(:call, original_retriever_call) if original_retriever_call
  end

  test "returns stable response shape when external analysis is present" do
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "The lease is silent on market practice.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    original_ai_call = AiClient.method(:call)
    AiClient.define_singleton_method(:call) do |_prompt|
      <<~ANSWER
        Insufficient document information to answer.

        External analysis:
        This is external to the package documents.
        Confidence: medium
        Rationale: The package does not include market comparison terms.
      ANSWER
    end

    post package_chatbot_sessions_url(@package),
         params: { question: "Is this market standard?", target: "package" },
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Insufficient document information to answer.", json["answer"]
    assert_includes json["external_analysis"], "This is external to the package documents."
    assert_equal "medium", json["external_confidence"]
    assert_equal "Is this market standard?", json.dig("user_message", "content")
    assert_includes json.dig("assistant_message", "content"), "External analysis:"
  ensure
    AiClient.define_singleton_method(:call, original_ai_call) if original_ai_call
  end

  test "returns safe error message when ai response fails" do
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "The lease term is 12 months and rents are due monthly.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    original_ai_call = AiClient.method(:call)
    AiClient.define_singleton_method(:call) do |_prompt|
      raise "GitHub Models request failed: 401 secret provider details"
    end

    assert_difference("ChatMessage.count", 2) do
      post package_chatbot_sessions_url(@package),
           params: { question: "What is the lease term?", target: "package" },
           as: :json
    end

    assert_response :internal_server_error
    json = JSON.parse(response.body)
    assert_equal "Chatbot response failed. Please try again.", json["error"]
    assert_equal "What is the lease term?", json.dig("user_message", "content")
    assert_equal "user", json.dig("user_message", "role")
    assert_equal "Sorry, I couldn't generate a response. Please try again.", json.dig("assistant_message", "content")
    assert_equal "assistant", json.dig("assistant_message", "role")
    assert_equal "Sorry, I couldn't generate a response. Please try again.", json["answer"]
    assert_nil json["external_analysis"]
    assert_nil json["external_confidence"]
    assert_not_includes response.body, "GitHub Models request failed"
    assert_not_includes response.body, "secret provider details"

    roles = @package.chat_messages.order(:created_at).pluck(:role)
    assert_equal [ "user", "assistant" ], roles
  ensure
    AiClient.define_singleton_method(:call, original_ai_call) if original_ai_call
  end

  test "passes recent chat history into the prompt" do
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "The lease term is 12 months and rents are due monthly.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    @package.chat_messages.create!(user: @user, role: "user", content: "Oldest message outside memory window")
    10.times do |index|
      @package.chat_messages.create!(user: @user, role: index.even? ? "user" : "assistant", content: "Recent message #{index + 1}")
    end

    captured_prompt = nil
    original_ai_call = AiClient.method(:call)
    AiClient.define_singleton_method(:call) do |prompt|
      captured_prompt = prompt
      "The lease term is 12 months."
    end

    post package_chatbot_sessions_url(@package),
         params: { question: "Can you compare that to the rent schedule?", target: "package" },
         as: :json

    assert_response :success
    assert_includes captured_prompt, "Conversation history:"
    assert_includes captured_prompt, "Recent message 1"
    assert_includes captured_prompt, "Recent message 10"
    assert_not_includes captured_prompt, "Oldest message outside memory window"
    assert_includes captured_prompt, "Current question:\nCan you compare that to the rent schedule?"
  ensure
    AiClient.define_singleton_method(:call, original_ai_call) if original_ai_call
  end

  test "returns not_found for another user's package" do
    other = User.create!(email: "other@example.com", password: "password", username: "other")
    other_package = other.packages.create!(name: "Private")

    get package_chatbot_sessions_url(other_package), as: :json
    assert_response :not_found

    assert_no_difference("ChatMessage.count") do
      post package_chatbot_sessions_url(other_package), params: { question: "hi" }, as: :json
      assert_response :not_found
    end
  end
end
