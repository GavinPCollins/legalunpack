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
end
