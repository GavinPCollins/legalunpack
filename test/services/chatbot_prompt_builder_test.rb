require "test_helper"

class ChatbotPromptBuilderTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "prompt@example.com", password: "password", username: "prompt")
    @package = @user.packages.create!(name: "Lease review")
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "The lease term is 12 months.",
      file: {
        io: StringIO.new("The lease term is 12 months."),
        filename: "sample.txt",
        content_type: "text/plain"
      }
    )
  end

  test "includes conversation history separately from the current question" do
    history = [
      @package.chat_messages.create!(user: @user, role: "user", content: "What is the lease term?"),
      @package.chat_messages.create!(user: @user, role: "assistant", content: "The lease term is 12 months.")
    ]

    prompt = ChatbotPromptBuilder.build(
      @package,
      question: "When does it renew?",
      history: history
    )

    assert_includes prompt, "Conversation history:"
    assert_includes prompt, "User: What is the lease term?"
    assert_includes prompt, "Assistant: The lease term is 12 months."
    assert_includes prompt, "Current question:\nWhen does it renew?"
  end

  test "keeps document text as the primary source over history" do
    prompt = ChatbotPromptBuilder.build(@package, question: "What is the lease term?")

    assert_includes prompt, "Use the document text provided below as the PRIMARY source."
    assert_includes prompt, "Do not treat conversation history as a source of document facts"
    assert_includes prompt, "No prior conversation."
  end
end
