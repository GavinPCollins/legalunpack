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
end
