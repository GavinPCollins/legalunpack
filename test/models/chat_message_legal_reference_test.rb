require "test_helper"

class ChatMessageLegalReferenceTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "chatref@example.com", password: "password", username: "chatref")
    package = user.packages.create!(name: "Consumer review")
    @message = package.chat_messages.create!(user: user, role: "assistant", content: "Check [L1].")
    source = LegalSource.create!(
      title: "Refunds and returns",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_url: "https://www.consumer.vic.gov.au/refunds",
      source_format: "html"
    )
    @chunk = source.legal_source_chunks.create!(
      heading: "Major problems",
      content: "Consumers may be entitled to a refund when goods have a major problem.",
      position: 1
    )
  end

  test "belongs to an assistant message and legal source chunk" do
    reference = @message.chat_message_legal_references.create!(
      legal_source_chunk: @chunk,
      label: "L1"
    )

    assert_equal @message, reference.chat_message
    assert_equal @chunk, reference.legal_source_chunk
  end
end
