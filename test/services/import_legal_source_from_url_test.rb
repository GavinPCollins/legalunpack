require "test_helper"

class ImportLegalSourceFromUrlTest < ActiveSupport::TestCase
  test "imports text from an attached source file into chunks" do
    legal_source = LegalSource.create!(
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

    ImportLegalSourceFromUrl.call(legal_source)

    assert_equal "Sample legal text.", legal_source.reload.raw_text
    assert legal_source.imported?
    assert_equal 1, legal_source.legal_source_chunks.count
    assert_equal "Sample legal text.", legal_source.legal_source_chunks.first.content
  end
end
