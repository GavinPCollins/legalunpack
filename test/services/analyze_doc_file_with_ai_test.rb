require "test_helper"

class AnalyzeDocFileWithAiTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "analyze@example.com", password: "password", username: "analyze")
    @package = user.packages.create!(name: "Lease review")
    @doc_file = @package.doc_files.create!(
      extracted_text: "Payment is due within 14 days.",
      extraction_status: "complete",
      file: {
        io: StringIO.new("Payment is due within 14 days."),
        filename: "sample.txt",
        content_type: "text/plain"
      }
    )
  end

  test "returns parsed clause data from the ai response" do
    doc_file = DocFile.new(extracted_text: "Payment is due within 14 days.")
    raw_response = {
      clauses: [
        {
          title: "Payment",
          content: "Payment is due within 14 days.",
          risk_level: "low",
          summary: "Sets a short payment deadline."
        }
      ]
    }.to_json
    captured_prompt = nil
    captured_json_response = nil

    original_ai_call = AiClient.method(:call)
    AiClient.define_singleton_method(:call) do |prompt, json_response: false, **|
      captured_prompt = prompt
      captured_json_response = json_response
      raw_response
    end

    result = AnalyzeDocFileWithAi.call(doc_file)

    assert_equal "Payment", result.dig("clauses", 0, "title")
    assert_equal "low", result.dig("clauses", 0, "risk_level")
    assert_equal true, captured_json_response
    assert_includes captured_prompt, "micro_summary"
    assert_includes captured_prompt, "Payment is due within 14 days."
  ensure
    AiClient.define_singleton_method(:call, original_ai_call) if original_ai_call
  end

  test "requires extracted text" do
    doc_file = DocFile.new(extracted_text: "")

    assert_raises ArgumentError do
      AnalyzeDocFileWithAi.call(doc_file)
    end
  end

  test "saves parsed clauses to the doc file and package" do
    raw_response = {
      summary: "This file sets payment and termination obligations.",
      micro_summary: "Payment and termination obligations.",
      clauses: [
        {
          title: "Payment",
          content: "Payment is due within 14 days.",
          risk_level: "low",
          summary: "Sets a short payment deadline."
        },
        {
          title: "Termination",
          content: "Either party may terminate with notice.",
          risk_level: "medium",
          summary: "Allows termination after notice."
        }
      ]
    }.to_json

    stub_ai_response(raw_response) do
      assert_difference("Clause.count", 2) do
        AnalyzeDocFileWithAi.save!(@doc_file)
      end
    end

    first_clause, second_clause = @doc_file.clauses.order(:position)

    assert_equal [ first_clause, second_clause ], @package.clauses.order(:position).to_a
    assert_equal "Payment", first_clause.title
    assert_equal "low", first_clause.risk_level
    assert_equal "Sets a short payment deadline.", first_clause.summary
    assert_equal 1, first_clause.position
    assert_equal "Termination", second_clause.title
    assert_equal "medium", second_clause.risk_level
    assert_equal 2, second_clause.position

    @doc_file.reload
    assert_equal "complete", @doc_file.ai_status
    assert_equal "This file sets payment and termination obligations.", @doc_file.ai_summary
    assert_equal "Payment and termination obligations.", @doc_file.ai_micro_summary
    assert_nil @doc_file.ai_error
    assert_not_nil @doc_file.ai_processed_at
  end

  test "replaces existing clauses when saving analysis again" do
    @doc_file.clauses.create!(
      package: @package,
      title: "Old clause",
      content: "Old content.",
      risk_level: "high",
      summary: "Old summary.",
      position: 1
    )
    raw_response = {
      clauses: [
        {
          title: "New clause",
          content: "New content.",
          risk_level: "low",
          summary: "New summary."
        }
      ]
    }.to_json

    stub_ai_response(raw_response) do
      assert_no_difference("Clause.count") do
        AnalyzeDocFileWithAi.save!(@doc_file)
      end
    end

    clause = @doc_file.clauses.first

    assert_equal "New clause", clause.title
    assert_equal "New content.", clause.content
  end

  test "marks ai analysis failed when parsing fails" do
    stub_ai_response("not json") do
      assert_raises JSON::ParserError do
        AnalyzeDocFileWithAi.save!(@doc_file)
      end
    end

    @doc_file.reload

    assert_equal "failed", @doc_file.ai_status
    assert_includes @doc_file.ai_error, "unexpected"
    assert_nil @doc_file.ai_processed_at
  end

  private

  def stub_ai_response(raw_response)
    original_ai_call = AiClient.method(:call)
    AiClient.define_singleton_method(:call) do |*, **|
      raw_response
    end

    yield
  ensure
    AiClient.define_singleton_method(:call, original_ai_call) if original_ai_call
  end
end
