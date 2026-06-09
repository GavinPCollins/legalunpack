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
      doc = package.doc_files.find_by(id: target_id)
      context_parts << doc.extracted_text.to_s if doc&.extraction_status == "complete"
    when "clause"
      clause = package.clauses.find_by(id: target_id)
      context_parts << clause.content.to_s if clause
      context_parts << clause.summary.to_s if clause&.summary.present?
    else
      # package-wide: include all completed extracted_text
      texts = package.doc_files.where(extraction_status: "complete").pluck(:extracted_text)
      context_parts.concat(texts.compact)
    end

    context = context_parts.reject(&:blank?).join("\n\n")

    header = <<~HEADER
      You are a helpful legal assistant. Use the document text provided below as the PRIMARY source.
      First, attempt to answer STRICTLY and ONLY from the document text. If the documents contain enough information, answer using ONLY those documents and cite the relevant text where possible.

      Use the conversation history only to understand follow-up questions, references, and context from the user. Do not treat conversation history as a source of document facts unless those facts are supported by the document text.

      If the documents do NOT contain enough information to answer the question, first state exactly: "Insufficient document information to answer." Then, optionally provide an additional section titled "External analysis" where you MAY apply general legal principles or common practice to offer interpretation.

      The legal reference material, if provided, is supporting context retrieved by the app. Use it only when relevant, cite it as [L1], [L2], etc., and never invent legislation, sections, regulators, or citations that are not shown there.

      In the "External analysis" section you MUST:
      - Clearly mark that the material is external to the package documents.
      - Give a confidence level (high / medium / low) for any external interpretation.
      - Provide a one-line rationale for why external knowledge was needed.

      Do not present external analysis as definitive legal advice; recommend human review when appropriate.
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
      1) A concise answer strictly from the document text (if available).
      2) If insufficient, a labeled "External analysis" section (see rules above).

      Keep the answer concise and clearly separate document-based findings from any external reasoning.
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
        reference.title,
        reference.heading,
        reference.publisher,
        reference.jurisdiction,
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
