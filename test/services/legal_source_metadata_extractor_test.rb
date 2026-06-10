require "test_helper"

class LegalSourceMetadataExtractorTest < ActiveSupport::TestCase
  FakeAiClient = Struct.new(:response, keyword_init: true) do
    attr_reader :prompt, :json_response

    def call(prompt, json_response: false)
      @prompt = prompt
      @json_response = json_response
      response
    end
  end

  test "extracts metadata from text file using AI JSON response" do
    ai_client = FakeAiClient.new(response: {
      title: "Residential Tenancies Act 1997",
      citation: "Authorised Version No. 111",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      publisher: "Victorian Legislation",
      source_format: "txt"
    }.to_json)
    uploaded_file = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample.txt"),
      "text/plain"
    )

    metadata = LegalSourceMetadataExtractor.call(uploaded_file, ai_client: ai_client)

    assert_equal "Residential Tenancies Act 1997", metadata["title"]
    assert_equal "Victorian Legislation", metadata["publisher"]
    assert ai_client.json_response
    assert_includes ai_client.prompt, "Return ONLY a JSON object"
  end
end
