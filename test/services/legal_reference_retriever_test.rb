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

  test "builds pinpoint citations for legislation chunks" do
    source = LegalSource.create!(
      title: "Residential Tenancies Act 1997",
      citation: "Authorised Version No. 111",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      publisher: "Victorian Legislation",
      source_url: "https://example.com/residential-tenancies-act",
      source_format: "txt"
    )
    source.legal_source_chunks.create!(
      heading: "91Z Notice of intention to vacate",
      content: "A renter may give a residential rental provider a notice of intention to vacate.",
      position: 1
    )

    results = LegalReferenceRetriever.call(query: "notice of intention to vacate", jurisdiction: "VIC")

    assert_equal "act", results.first.source_type
    assert_equal "91Z", results.first.pinpoint
    assert_equal "Authorised Version No. 111, 91Z", results.first.citation
  end

  test "prefers direct provision heading matches from wider candidates" do
    source = LegalSource.create!(
      title: "Residential Tenancies Regulations 2021",
      citation: "S.R. No. 3/2021",
      jurisdiction: "VIC",
      source_type: "regulation",
      authority_level: "regulation",
      publisher: "Victorian Legislation",
      source_url: "https://example.com/residential-tenancies-regulations",
      source_format: "txt"
    )
    source.legal_source_chunks.create!(
      heading: "Background notes",
      content: "Rent increase notice regulation form renter rent increase notice regulation.",
      position: 1
    )
    source.legal_source_chunks.create!(
      heading: "21 Form of notice of rent increase to renter",
      content: "The prescribed form of notice of rent increase to a renter is set out here.",
      position: 2
    )

    results = LegalReferenceRetriever.call(query: "rent increase notice regulation", jurisdiction: "VIC", limit: 1)

    assert_equal "21 Form of notice of rent increase to renter", results.first.heading
    assert_equal "S.R. No. 3/2021, 21", results.first.citation
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
