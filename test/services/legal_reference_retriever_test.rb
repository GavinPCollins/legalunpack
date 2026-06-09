require "test_helper"

class LegalReferenceRetrieverTest < ActiveSupport::TestCase
  test "returns matching legal source chunks with source metadata" do
    source = LegalSource.create!(
      title: "Refunds and returns",
      citation: "Consumer Affairs Victoria refunds guidance",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      publisher: "Consumer Affairs Victoria",
      source_url: "https://www.consumer.vic.gov.au/refunds",
      source_format: "html"
    )
    source.legal_source_chunks.create!(
      heading: "Major problems",
      content: "Consumers may be entitled to a refund when goods have a major problem.",
      position: 1
    )

    results = LegalReferenceRetriever.call(query: "refund major problem", jurisdiction: "VIC")

    assert_equal 1, results.size
    assert_equal "L1", results.first.label
    assert_equal "Consumer Affairs Victoria refunds guidance", results.first.title
    assert_equal "Major problems", results.first.heading
    assert_includes results.first.content, "major problem"
  end

  test "filters by jurisdiction before limiting results" do
    nsw_source = LegalSource.create!(
      title: "NSW refund guidance",
      jurisdiction: "NSW",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_url: "https://example.com/nsw-refunds",
      source_format: "html"
    )
    nsw_source.legal_source_chunks.create!(
      heading: "Refunds",
      content: "Refund guidance for NSW consumer issues.",
      position: 1
    )
    vic_source = LegalSource.create!(
      title: "VIC refund guidance",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_url: "https://example.com/vic-refunds",
      source_format: "html"
    )
    vic_source.legal_source_chunks.create!(
      heading: "Refunds",
      content: "Refund guidance for VIC consumer issues.",
      position: 1
    )

    results = LegalReferenceRetriever.call(query: "refund guidance", jurisdiction: "VIC", limit: 1)

    assert_equal 1, results.size
    assert_equal "VIC", results.first.jurisdiction
  end
end
