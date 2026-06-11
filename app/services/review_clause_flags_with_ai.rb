require "json"
require "set"

class ReviewClauseFlagsWithAi
  DEFAULT_JURISDICTION = "VIC"
  EVIDENCE_BASES = %w[legal_reference commercial_risk legal_review].freeze
  DUPLICATE_SIMILARITY = 0.75

  ReviewedFlag = Struct.new(:attributes, :legal_references, keyword_init: true)

  def self.call(clause_data, retriever: LegalReferenceRetriever, jurisdiction: DEFAULT_JURISDICTION, on_stage: nil)
    new(clause_data, retriever: retriever, jurisdiction: jurisdiction, on_stage: on_stage).call
  end

  def initialize(clause_data, retriever:, jurisdiction:, on_stage:)
    @clause_data = clause_data
    @retriever = retriever
    @jurisdiction = jurisdiction
    @on_stage = on_stage
  end

  def call
    return [] if candidates.blank?

    on_stage&.call("checking_sources")
    references = retriever.call(query: retrieval_query, jurisdiction: jurisdiction)
    on_stage&.call("reviewing_concerns")
    response = JSON.parse(AiClient.call(review_prompt(references), json_response: true))

    distinct_flags(response["flags"]).filter_map do |flag_data|
      build_reviewed_flag(flag_data, references)
    end
  end

  private

  attr_reader :clause_data, :retriever, :jurisdiction, :on_stage

  def candidates
    @candidates ||= Array(clause_data["candidate_concerns"]).select { |candidate| candidate["name"].present? }
  end

  def retrieval_query
    [
      clause_data["title"],
      clause_data["summary"],
      clause_data["content"].to_s.truncate(2_000, separator: "\n\n"),
      candidates.pluck("name", "reason").flatten
    ].flatten.compact_blank.join("\n")
  end

  def distinct_flags(flags)
    Array(flags).each_with_object([]) do |flag_data, accepted|
      next if flag_data["name"].blank?
      next if accepted.any? { |existing| duplicate?(existing, flag_data) }

      accepted << flag_data
    end
  end

  def duplicate?(first, second)
    return true if normalize(first["name"]) == normalize(second["name"])
    return false unless first["category"].to_s == second["category"].to_s

    similarity(flag_terms(first), flag_terms(second)) >= DUPLICATE_SIMILARITY
  end

  def flag_terms(flag_data)
    normalize([ flag_data["name"], flag_data["reason"] ].compact.join(" ")).split.to_set
  end

  def similarity(first_terms, second_terms)
    union = first_terms | second_terms
    return 0.0 if union.empty?

    (first_terms & second_terms).size.to_f / union.size
  end

  def normalize(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def build_reviewed_flag(flag_data, references)
    reference_labels = Array(flag_data["legal_reference_labels"]).map(&:to_s)
    matched_references = references.select { |reference| reference_labels.include?(reference.label) }
    evidence_basis = normalized_evidence_basis(flag_data["evidence_basis"], matched_references)

    ReviewedFlag.new(
      attributes: {
        name: flag_data["name"],
        reason: flag_data["reason"],
        details: flag_data["details"],
        level: normalized_level(flag_data["level"]),
        category: normalized_category(flag_data["category"]),
        evidence_basis: evidence_basis,
        suggested_action: flag_data["suggested_action"]
      },
      legal_references: matched_references
    )
  end

  def normalized_evidence_basis(value, references)
    basis = value if EVIDENCE_BASES.include?(value)
    return "legal_review" if basis == "legal_reference" && references.blank?

    basis || "commercial_risk"
  end

  def normalized_level(value)
    value if Flag::LEVELS.include?(value)
  end

  def normalized_category(value)
    value if Flag::CATEGORIES.include?(value)
  end

  def review_prompt(references)
    <<~PROMPT
      You are performing a conservative contract risk review. Return only valid JSON:
      {
        "flags": [
          {
            "name": "string",
            "reason": "A concise 1-2 sentence summary of the concern.",
            "details": "A fuller plain-English explanation of the wording, risk, and likely consequence.",
            "level": "low|medium|high",
            "category": "deadline|missing_information|negotiation_point|legal_review|document_check|commercial_decision|unclear_term",
            "evidence_basis": "legal_reference|commercial_risk|legal_review",
            "legal_reference_labels": ["L1"],
            "suggested_action": "One practical next step."
          }
        ]
      }

      Review the candidate concerns and keep only concerns that could materially disadvantage the document owner.

      A flag is justified only when the clause plausibly:
      - conflicts with supplied law, regulation, or authoritative guidance;
      - creates material financial, liability, privacy, operational, or termination exposure;
      - is unusually one-sided or meaningfully outside ordinary contractual expectations;
      - omits an important protection in a way that creates real risk; or
      - is materially ambiguous and likely to cause a dispute, loss, or inability to enforce rights.

      Do not flag:
      - routine or market-standard obligations merely because they impose duties;
      - ordinary deadlines, notice steps, record keeping, or administrative requirements;
      - clauses that are simply important to understand;
      - minor drafting imperfections without a plausible material consequence;
      - speculative concerns unsupported by the clause;
      - repeated or slightly reworded versions of the same underlying concern.

      Consolidate closely related concerns into one flag. Keep separate flags only when the risks are genuinely independent and require different actions.
      Prefer a small number of high-value flags. Returning an empty flags array is correct when the clause is ordinary or no material concern is supported.

      Use evidence_basis "legal_reference" only when the concern is supported by one or more supplied legal references, and include their labels.
      Never state or imply that wording is unlawful without a supplied supporting reference.
      Use "commercial_risk" for material risks evident from the contract wording without a legal conclusion.
      Use "legal_review" when a material concern remains uncertain and professional review is genuinely warranted.

      Clause:
      #{JSON.pretty_generate(clause_data.slice("title", "content", "summary", "risk_level"))}

      Candidate concerns:
      #{JSON.pretty_generate(candidates)}

      Retrieved legal references:
      #{legal_references_prompt(references)}
    PROMPT
  end

  def legal_references_prompt(references)
    return "No legal reference material retrieved." if references.blank?

    references.map do |reference|
      <<~REFERENCE.squish
        [#{reference.label}] #{reference.citation} | #{reference.publisher} | #{reference.jurisdiction} |
        #{reference.source_type} | #{reference.authority_level}
        Text: #{reference.content.to_s.truncate(2_000, separator: " ")}
      REFERENCE
    end.join("\n\n")
  end
end
