require "test_helper"

class LegalSourceTest < ActiveSupport::TestCase
  test "is valid with a source url" do
    legal_source = LegalSource.new(
      title: "Residential Tenancies Act 1997",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      publisher: "Victorian Legislation",
      source_url: "https://example.com/residential-tenancies",
      source_format: "html"
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
