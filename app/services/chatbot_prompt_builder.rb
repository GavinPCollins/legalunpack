class ChatbotPromptBuilder
  # Build a prompt that restricts the model to only use provided package text.
  # Params:
  # - package: Package
  # - question: String
  # - target: "package" | "doc_file" | "clause"
  # - target_id: id for doc_file or clause when applicable
  # - history: previous ChatMessage records for follow-up context
  def self.build(package, question:, target: "package", target_id: nil, history: [], legal_references: nil) # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity
    context_parts = []

    case target.to_s
    when "doc_file"
      doc = package.doc_files.active.find_by(id: target_id)
      context_parts << doc.extracted_text.to_s if doc&.extraction_status == "complete"
    when "clause"
      clause = package.clauses.find_by(id: target_id)
      context_parts << clause.content.to_s if clause
      context_parts << clause.summary.to_s if clause&.summary.present?
    else
      # package-wide: include all completed extracted_text
      texts = package.doc_files.active.where(extraction_status: "complete").pluck(:extracted_text)
      context_parts.concat(texts.compact)
    end

    context = context_parts.reject(&:blank?).join("\n\n")

    header = <<~HEADER
      You are a helpful legal assistant. Use the document text and retrieved legal reference material together to answer the user's question.
      Treat the document text as the source for what the package says, and the legal reference material as the source for relevant legal or regulatory context. Cite the source you rely on where possible.

      Use the conversation history only to understand follow-up questions, references, and context from the user. Do not treat conversation history as a source of document facts unless those facts are supported by the document text.

      If the document text and retrieved legal references together do NOT contain enough information to answer the question, say what is missing. Then, optionally provide a section titled "External analysis" where you MAY apply clearly marked general legal principles or common practice.

      The legal reference material is retrieved by the app. Use it when it helps answer the question, cite it as [L1], [L2], etc., and never invent legislation, sections, regulations, regulators, or citations that are not shown there.
      When legal reference material comes from an Act or Regulation, cite the provided citation exactly, including the pinpoint section/regulation/part/schedule where shown.

      In the "External analysis" section you MUST:
      - Clearly mark that the material is not directly stated in the document text or retrieved legal references.
      - Give a confidence level (high / medium / low) for any external interpretation.
      - Provide a one-line rationale for why extra reasoning was needed.

      Do not present external analysis as definitive legal advice; recommend human review when appropriate.

      Response style:
      - Start with a 1-2 sentence direct answer that gives immediate context.
      - Then use short sections with clear labels when helpful: "Why", "Relevant terms", "Legal references", "Risks", "Next step".
      - Prefer 3-6 concise bullets over long paragraphs.
      - Do not paste large blocks from the document or legal references. Quote only short phrases when needed.
      - If legal reference material materially informs the answer, include a short "Legal references" section naming the relevant source title or Act/Regulation citation and citation label, for example: "[L1] Residential Tenancies Act 1997 (VIC), s 91Z - explains when this notice may apply."
      - When citing legal reference material, explain why the reference matters in plain English before citing [L1], [L2], etc.
      - If a legal reference is retrieved but not actually relevant, ignore it.
      - If the answer is uncertain, say what is missing rather than filling the gap with assumptions.
    HEADER

    prompt_body = if context.blank?
                    "The package does not have completed extracted text for the requested scope."
                  else
                    context.truncate(28_000, separator: "\n\n")
                  end

    history_body = history_prompt(history)
    legal_references ||= LegalReferenceRetriever.call(query: question)
    legal_references_body = legal_references_prompt(legal_references)

    <<~PROMPT
      #{header}

      Package: #{package.name.presence || '(untitled)'}
      Scope: #{target}

      Document text:
      #{prompt_body}

      Legal reference material:
      #{legal_references_body}

      Conversation history:
      #{history_body}

      Current question:
      #{question}

      Answer in two possible parts as needed:
      1) A concise answer grounded in the document text and any relevant legal reference material.
      2) If those sources are insufficient, a labeled "External analysis" section with clearly marked general reasoning.

      Keep the answer concise and structured. Clearly separate what the document says, what the legal references say, and any extra reasoning.
    PROMPT
  end

  def self.history_prompt(history)
    lines = Array(history).map do |message|
      role = message.role.to_s.capitalize.presence || "Message"
      content = message.content.to_s.strip.truncate(1_000, separator: " ")

      next if content.blank?

      "#{role}: #{content}"
    end.compact

    return "No prior conversation." if lines.blank?

    lines.join("\n\n").truncate(6_000, separator: "\n\n")
  end
  private_class_method :history_prompt

  def self.legal_references_prompt(legal_references)
    references = Array(legal_references).first(5)
    return "No legal reference material retrieved." if references.blank?

    references.map do |reference|
      source_parts = [
        reference.citation.presence || reference.title,
        reference.heading,
        reference.publisher,
        reference.jurisdiction,
        reference.source_type,
        reference.authority_level
      ].compact_blank

      <<~REFERENCE.squish
        [#{reference.label}] #{source_parts.join(" | ")}
        Source: #{reference.source_url}
        Text: #{reference.content.to_s.truncate(2_000, separator: " ")}
      REFERENCE
    end.join("\n\n")
  end
  private_class_method :legal_references_prompt
end
