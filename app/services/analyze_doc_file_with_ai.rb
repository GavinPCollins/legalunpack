require "json"

# Takes one DocFile, sends its extracted text to the AI, and returns parsed JSON.
class AnalyzeDocFileWithAi
  # Public entrypoint: AnalyzeDocFileWithAi.call(doc_file)
  def self.call(doc_file)
    new(doc_file).call
  end

  # Public entrypoint: AnalyzeDocFileWithAi.save!(doc_file)
  def self.save!(doc_file)
    new(doc_file).save!
  end

  # Store the file we want to analyse.
  def initialize(doc_file)
    @doc_file = doc_file
  end

  def call
    # The AI can only work once text extraction has already completed.
    raise ArgumentError, "doc file must have extracted text" if @doc_file.extracted_text.blank?

    # Ask AiClient for a JSON-formatted response.
    raw_response = AiClient.call(prompt, json_response: true)

    # Convert the JSON string into a Ruby hash.
    JSON.parse(raw_response)
  end

  def save!
    @doc_file.update!(ai_status: "processing")

    result = call

    Clause.transaction do
      @doc_file.clauses.destroy_all

      Array(result["clauses"]).each.with_index(1) do |clause_data, position|
        @doc_file.clauses.create!(
          package: @doc_file.package,
          title: clause_data["title"],
          content: clause_data["content"],
          risk_level: clause_data["risk_level"],
          summary: clause_data["summary"],
          position: position
        )
      end

      @doc_file.update!(
        ai_summary: result["summary"],
        ai_status: "complete",
        ai_error: nil,
        ai_processed_at: Time.current
      )
    end
  rescue StandardError => error
    @doc_file.update!(
      ai_status: "failed",
      ai_error: error.message,
      ai_processed_at: nil
    )

    raise
  end

  private

  # Prompt goes here
  def prompt
    <<~PROMPT
      Return only valid JSON in this shape:
      {
        "clauses": [
          {
            "title": "string",
            "content": "string",
            "risk_level": "low|medium|high",
            "summary": "string"
          }
        ]
      }

      Document text:
      #{@doc_file.extracted_text}
    PROMPT
  end
end
