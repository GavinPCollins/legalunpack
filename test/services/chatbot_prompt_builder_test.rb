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

  test "uses document text and legal references while keeping history contextual" do
    prompt = ChatbotPromptBuilder.build(@package, question: "What is the lease term?")

    assert_includes prompt, "Use the document text and retrieved legal reference material together"
    assert_includes prompt, "Treat the document text as the source for what the package says"
    assert_includes prompt, "Do not treat conversation history as a source of document facts"
    assert_includes prompt, "Start with a 1-2 sentence direct answer that gives immediate context."
    assert_includes prompt, "Prefer 3-6 concise bullets over long paragraphs."
    assert_includes prompt, "Do not paste large blocks from the document or legal references."
    assert_includes prompt, "No prior conversation."
  end

  test "includes retrieved legal references as supporting context" do
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
    reference = LegalReferenceRetriever::Result.new(number: 1, chunk: chunk)

    prompt = ChatbotPromptBuilder.build(
      @package,
      question: "Does this mention refunds?",
      legal_references: [ reference ]
    )

    assert_includes prompt, "Legal reference material:"
    assert_includes prompt, "[L1] Refunds and returns | Major problems | Consumer Affairs Victoria | VIC | guidance"
    assert_includes prompt, "Use it when it helps answer the question, cite it as [L1], [L2]"
    assert_includes prompt, "Consumers may be entitled to a refund"
  end
end
