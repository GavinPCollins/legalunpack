require "json"

# Takes one DocFile, sends its extracted text to the AI, and returns parsed JSON.
class AnalyzeDocFileWithAi
  def self.call(doc_file)
    new(doc_file).call
  end

  def self.save!(doc_file)
    new(doc_file).save!
  end

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

    persist_analysis!(call)
  rescue StandardError => e
    mark_analysis_failed!(e)

    raise
  end

  private

  def persist_analysis!(result)
    Clause.transaction do
      @doc_file.clauses.destroy_all
      Array(result["clauses"]).each.with_index(1) do |clause_data, position|
        create_clause_from_analysis(clause_data, position)
      end
      mark_analysis_complete!(result)
    end
  end

  def mark_analysis_complete!(result)
    @doc_file.update!(
      ai_summary: result["summary"],
      ai_micro_summary: result["micro_summary"].presence || result["summary"],
      ai_status: "complete",
      ai_error: nil,
      ai_processed_at: Time.current
    )
  end

  def mark_analysis_failed!(error)
    @doc_file.update!(
      ai_status: "failed",
      ai_error: error.message,
      ai_processed_at: nil
    )
  end

  def create_clause_from_analysis(clause_data, position)
    clause = @doc_file.clauses.create!(
      package: @doc_file.package,
      title: clause_data["title"],
      content: clause_data["content"],
      risk_level: clause_data["risk_level"],
      summary: clause_data["summary"],
      position: position
    )

    create_flags_for(clause, clause_data["flags"])
  end

  def create_flags_for(clause, flags_data)
    Array(flags_data).each do |flag_data|
      next if flag_data["name"].blank?

      clause.flags.create!(
        name: flag_data["name"],
        reason: flag_data["reason"],
        level: flag_level(flag_data["level"])
      )
    end
  end

  def flag_level(value)
    value if Flag::LEVELS.include?(value)
  end

  def prompt
    <<~PROMPT
      Return only valid JSON in this shape:
      {
        "summary": "A short plain-English summary of the whole file.",
        "micro_summary": "A very short summary of the whole file in 8 words or fewer.",
        "clauses": [
          {
            "title": "string",
            "content": "string",
            "risk_level": "low|medium|high",
            "summary": "string",
            "flags": [{ "name": "string", "reason": "string", "level": "low|medium|high" }]
          }
        ]
      }

      Identify clauses that may be important for the document owner to understand or act on.
      Use risk_level to describe the seriousness of the clause itself.

      Do not create a flag merely because a clause is high risk.
      A high-risk clause should draw attention to a potentially serious issue, but it does not automatically require a flag.

      Add flags only where the clause requires a concrete follow-up action, clarification, deadline tracking, document check, review, or unresolved decision.
      Use flag level to describe the urgency or priority of that follow-up action.
      For clauses that do not require concrete follow-up, return an empty flags array, even if the clause is high risk.

      Document text:
      #{@doc_file.extracted_text}
    PROMPT
  end
end
