require "test_helper"

class ReviewClauseFlagsWithAiTest < ActiveSupport::TestCase
  test "keeps distinct material flags and removes repeated concerns" do
    response = {
      flags: [
        {
          name: "Uncapped repair liability",
          reason: "The tenant may have unlimited repair costs.",
          details: "The clause does not limit the tenant's exposure.",
          level: "high",
          category: "commercial_decision",
          evidence_basis: "commercial_risk",
          legal_reference_labels: [],
          suggested_action: "Negotiate a reasonable cap."
        },
        {
          name: "Uncapped repair liability",
          reason: "Repair costs are not capped.",
          level: "high",
          category: "commercial_decision",
          evidence_basis: "commercial_risk",
          legal_reference_labels: []
        },
        {
          name: "Restricted repair reporting",
          reason: "The reporting method may prevent urgent notice.",
          level: "medium",
          category: "unclear_term",
          evidence_basis: "legal_review",
          legal_reference_labels: []
        }
      ]
    }.to_json

    stub_ai_response(response) do
      flags = ReviewClauseFlagsWithAi.call(clause_data, retriever: EmptyRetriever)

      assert_equal 2, flags.size
      assert_equal [ "Uncapped repair liability", "Restricted repair reporting" ], flags.map { |flag| flag.attributes[:name] }
    end
  end

  test "downgrades unsupported legal claims to legal review" do
    response = {
      flags: [
        {
          name: "Potentially unlawful repair term",
          reason: "The term may conflict with repair obligations.",
          level: "high",
          category: "legal_review",
          evidence_basis: "legal_reference",
          legal_reference_labels: [ "L9" ],
          suggested_action: "Obtain legal advice."
        }
      ]
    }.to_json

    stub_ai_response(response) do
      flag = ReviewClauseFlagsWithAi.call(clause_data, retriever: EmptyRetriever).first

      assert_equal "legal_review", flag.attributes[:evidence_basis]
      assert_empty flag.legal_references
    end
  end

  test "keeps legal evidence only when the returned label was retrieved" do
    reference = Reference.new("L1", "Residential Tenancies Act 1997 (VIC), s 68", nil)
    response = {
      flags: [
        {
          name: "Repair obligation may conflict with legislation",
          reason: "The clause may transfer a statutory repair obligation.",
          level: "high",
          category: "legal_review",
          evidence_basis: "legal_reference",
          legal_reference_labels: [ "L1" ],
          suggested_action: "Compare the clause with the cited provision."
        }
      ]
    }.to_json

    stub_ai_response(response) do
      flag = ReviewClauseFlagsWithAi.call(clause_data, retriever: StaticRetriever.new([ reference ])).first

      assert_equal "legal_reference", flag.attributes[:evidence_basis]
      assert_equal [ reference ], flag.legal_references
    end
  end

  test "returns no flags when there are no candidate concerns" do
    assert_empty ReviewClauseFlagsWithAi.call(clause_data.merge("candidate_concerns" => []), retriever: EmptyRetriever)
  end

  test "reports source and concern review stages" do
    stages = []

    stub_ai_response({ flags: [] }.to_json) do
      ReviewClauseFlagsWithAi.call(
        clause_data,
        retriever: EmptyRetriever,
        on_stage: ->(stage) { stages << stage }
      )
    end

    assert_equal %w[checking_sources reviewing_concerns], stages
  end

  private

  EmptyRetriever = Object.new.tap do |retriever|
    def retriever.call(**)
      []
    end
  end
  Reference = Struct.new(:label, :citation, :chunk) do
    def publisher = "Consumer Affairs Victoria"
    def jurisdiction = "VIC"
    def source_type = "act"
    def authority_level = "legislation"
    def content = "A renter must notify the rental provider about urgent repairs."
  end
  StaticRetriever = Struct.new(:references) do
    def call(**)
      references
    end
  end

  def clause_data
    {
      "title" => "Repairs",
      "content" => "The tenant must report and pay for all repairs.",
      "summary" => "Makes the tenant responsible for repairs.",
      "risk_level" => "high",
      "candidate_concerns" => [
        { "name" => "Repair responsibility", "reason" => "The tenant may carry broad repair obligations." }
      ]
    }
  end

  def stub_ai_response(response)
    original_ai_call = AiClient.method(:call)
    AiClient.define_singleton_method(:call) do |*, **|
      response
    end

    yield
  ensure
    AiClient.define_singleton_method(:call, original_ai_call) if original_ai_call
  end
end
