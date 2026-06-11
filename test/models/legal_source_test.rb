require "test_helper"

class LegalSourceTest < ActiveSupport::TestCase
  test "valid with trusted source metadata" do
    legal_source = LegalSource.new(
      title: "Refunds and returns",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_url: "https://www.consumer.vic.gov.au/refunds",
      source_format: "html"
    )

    assert legal_source.valid?
  end

  test "valid with an uploaded file instead of a source url" do
    legal_source = LegalSource.new(
      title: "Uploaded guidance",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_format: "txt",
      source_file: Rack::Test::UploadedFile.new(
        Rails.root.join("test/fixtures/files/sample.txt"),
        "text/plain"
      )
    )

    assert legal_source.valid?
  end

  test "requires a source url or uploaded file" do
    legal_source = LegalSource.new(
      title: "Residential Tenancies Act 1997",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      source_format: "txt"
    )

    assert_not legal_source.valid?
    assert_includes legal_source.errors.full_messages, "Add a source URL or upload a source file"
  end
end
