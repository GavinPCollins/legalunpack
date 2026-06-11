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
    @doc_file.update_columns(
      ai_status: "processing",
      analysis_stage: "analyzing_clauses",
      updated_at: Time.current
    )

    persist_analysis!(call)
  rescue StandardError => e
    mark_analysis_failed!(e)

    raise
  end

  private

  def persist_analysis!(result)
    reviewed_clauses = Array(result["clauses"]).map do |clause_data|
      [ clause_data, review_flags_for(clause_data) ]
    end
    @doc_file.update_columns(analysis_stage: "preparing_results", updated_at: Time.current)

    Clause.transaction do
      @doc_file.clauses.destroy_all
      reviewed_clauses.each.with_index(1) do |(clause_data, reviewed_flags), position|
        create_clause_from_analysis(clause_data, reviewed_flags, position)
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
      ai_processed_at: Time.current,
      analysis_stage: nil
    )
  end

  def mark_analysis_failed!(error)
    @doc_file.update!(
      ai_status: "failed",
      ai_error: error.message,
      ai_processed_at: nil,
      analysis_stage: nil
    )
  end

  def create_clause_from_analysis(clause_data, reviewed_flags, position)
    clause = @doc_file.clauses.create!(
      package: @doc_file.package,
      title: clause_data["title"],
      content: clause_data["content"],
      risk_level: clause_data["risk_level"],
      summary: clause_data["summary"],
      position: position
    )

    create_reviewed_flags_for(clause, reviewed_flags)
  end

  def review_flags_for(clause_data)
    ReviewClauseFlagsWithAi.call(
      clause_data,
      on_stage: ->(stage) {
        @doc_file.update_columns(analysis_stage: stage, updated_at: Time.current)
      }
    )
  end

  def create_reviewed_flags_for(clause, reviewed_flags)
    reviewed_flags.each do |reviewed_flag|
      flag = clause.flags.create!(reviewed_flag.attributes)

      reviewed_flag.legal_references.each do |reference|
        flag.flag_legal_references.create!(legal_source_chunk: reference.chunk)
      end
    end
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
            "candidate_concerns": [
              {
                "name": "string",
                "reason": "A concise description of a possible material concern to review."
              }
            ]
          }
        ]
      }

      Identify and accurately extract the meaningful clauses in the document.
      Use risk_level to describe the seriousness of the clause itself.

      Candidate concerns are provisional inputs for a separate conservative review. Include a candidate only when the wording may create material legal, financial, liability, privacy, operational, termination, enforceability, or unusually one-sided risk.
      Do not add candidates for routine or market-standard obligations, ordinary administrative steps, or clauses that are merely important to understand.
      Consolidate closely related possible concerns. Keep independent concerns separate.
      Return an empty candidate_concerns array when the clause appears ordinary or no plausible material concern is apparent.

      Document text:
      #{@doc_file.extracted_text}
    PROMPT
  end
end
