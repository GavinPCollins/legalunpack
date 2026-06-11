require "test_helper"

class LegalSourceChunkTest < ActiveSupport::TestCase
  test "requires content and positive position" do
    legal_source = LegalSource.create!(
      title: "Refunds and returns",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_url: "https://www.consumer.vic.gov.au/refunds",
      source_format: "html"
    )

    chunk = legal_source.legal_source_chunks.new(content: "Consumer guidance text.", position: 1)

    assert chunk.valid?
  end

  test "destroys saved chat references before deleting a chunk" do
    user = User.create!(email: "chunk-reference@example.com", password: "password", username: "chunkreference")
    package = user.packages.create!(name: "Lease review")
    message = package.chat_messages.create!(user: user, role: "assistant", content: "Review this against [L1].")
    legal_source = LegalSource.create!(
      title: "Residential Tenancies Act 1997",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      source_url: "https://example.com/residential-tenancies-act",
      source_format: "txt"
    )
    chunk = legal_source.legal_source_chunks.create!(
      heading: "91Z Notice of intention to vacate",
      content: "A renter may give notice of intention to vacate.",
      position: 1
    )
    message.chat_message_legal_references.create!(legal_source_chunk: chunk, label: "L1")

    assert_difference("ChatMessageLegalReference.count", -1) do
      chunk.destroy!
    end
  end
end
