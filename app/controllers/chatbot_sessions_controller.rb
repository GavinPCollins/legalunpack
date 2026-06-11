class ChatbotSessionsController < ApplicationController
  HISTORY_LIMIT = 10
  DEFAULT_INDEX_LIMIT = 50
  MAX_INDEX_LIMIT = 50
  DEFAULT_LEGAL_REFERENCE_JURISDICTION = "VIC"
  SAFE_ERROR_MESSAGE = "Chatbot response failed. Please try again."
  FAILED_ASSISTANT_MESSAGE = "Sorry, I couldn't generate a response. Please try again."

  # GET /packages/:package_id/chatbot_sessions
  def index
    package = current_user.packages.find(params[:package_id])
    messages = package.chat_messages.order(created_at: :desc, id: :desc).limit(index_limit).reverse

    render json: {
      messages: messages.map { |message| chat_message_json(message) }
    }
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  # POST /packages/:package_id/chatbot_sessions
  def create
    package = current_user.packages.find(params[:package_id])

    question = params[:question].to_s.strip
    target = params[:target].to_s.presence || "package"
    target_id = params[:target_id]

    return render json: { error: "Question can't be blank" }, status: :unprocessable_entity if question.blank?

    history = package.chat_messages.order(created_at: :desc).limit(HISTORY_LIMIT).reverse
    legal_references = legal_reference_retriever.call(
      query: legal_reference_query(package, question, target, target_id),
      jurisdiction: DEFAULT_LEGAL_REFERENCE_JURISDICTION
    )
    prompt = ChatbotPromptBuilder.build(
      package,
      question: question,
      target: target,
      target_id: target_id,
      history: history,
      legal_references: legal_references
    )

    user_message = package.chat_messages.create!(user: current_user, role: "user", content: question)
    answer = AiClient.call(prompt)
    assistant_message = package.chat_messages.create!(user: current_user, role: "assistant", content: answer)
    save_legal_references!(assistant_message, legal_references)

    render json: chat_response_json(user_message, assistant_message)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue StandardError => e
    Rails.logger.error("Chatbot response failed: #{e.class} - #{e.message}")

    if user_message&.persisted?
      assistant_message = package.chat_messages.create!(
        user: current_user,
        role: "assistant",
        content: FAILED_ASSISTANT_MESSAGE
      )

      render json: chat_response_json(user_message, assistant_message).merge(error: SAFE_ERROR_MESSAGE),
             status: :internal_server_error
    else
      render json: { error: SAFE_ERROR_MESSAGE }, status: :internal_server_error
    end
  end

  private

  def index_limit
    requested_limit = params[:limit].to_i
    return DEFAULT_INDEX_LIMIT if requested_limit <= 0

    [ requested_limit, MAX_INDEX_LIMIT ].min
  end

  def chat_message_json(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      created_at: message.created_at.iso8601,
      legal_references: legal_references_json(message)
    }
  end

  def chat_response_json(user_message, assistant_message)
    parsed_answer = parse_answer(assistant_message.content)

    {
      user_message: chat_message_json(user_message),
      assistant_message: chat_message_json(assistant_message),
      answer: parsed_answer[:answer],
      external_analysis: parsed_answer[:external_analysis],
      external_confidence: parsed_answer[:external_confidence],
      legal_references: legal_references_json(assistant_message)
    }
  end

  def legal_reference_query(package, question, target, target_id)
    context_parts = [ question ]

    case target.to_s
    when "doc_file"
      doc = package.doc_files.find_by(id: target_id)
      context_parts << doc.extracted_text.to_s.truncate(2_000, separator: "\n\n") if doc&.extraction_status == "complete"
    when "clause"
      clause = package.clauses.find_by(id: target_id)
      context_parts << clause.content.to_s if clause
      context_parts << clause.summary.to_s if clause&.summary.present?
    end

    context_parts.reject(&:blank?).join("\n\n")
  end

  def legal_reference_retriever
    LegalReferenceRetriever
  end

  def save_legal_references!(assistant_message, legal_references)
    Array(legal_references).each do |reference|
      assistant_message.chat_message_legal_references.create!(
        legal_source_chunk: reference.chunk,
        label: reference.label
      )
    end
  end

  def legal_references_json(message)
    message.chat_message_legal_references.includes(legal_source_chunk: :legal_source).order(:id).map do |reference|
      chunk = reference.legal_source_chunk
      source = chunk.legal_source

      {
        label: reference.label,
        title: source.citation.presence || source.title,
        citation: [ source.citation.presence || source.title, chunk.section_label.presence || pinpoint_from_heading(chunk.heading) ].compact_blank.join(", "),
        heading: chunk.heading.presence || chunk.section_label,
        publisher: source.publisher,
        jurisdiction: source.jurisdiction,
        source_type: source.source_type,
        authority_level: source.authority_level,
        source_url: source.source_url,
        content: chunk.content
      }
    end
  end

  def parse_answer(answer)
    external_section_regex = /\A(.*?)(?:\r?\n)?^\s*External analysis[:\s]*\r?\n(.*)\z/im
    match = answer.match(external_section_regex)

    return { answer: answer, external_analysis: nil, external_confidence: nil } unless match

    document_answer = match[1].to_s.strip
    external_text = match[2].to_s.strip
    confidence = external_text.match(/confidence\s*[:-]\s*(high|medium|low)/i)&.[](1)&.downcase

    {
      answer: document_answer.presence,
      external_analysis: external_text.presence,
      external_confidence: confidence
    }
  end

  def pinpoint_from_heading(heading)
    heading.to_s.match(/\A((?:section|s|regulation|reg|clause|part|division|schedule)\s+\d+[a-z]*|[0-9]+[A-Z]{0,3}[a-z]?)\b/i)&.[](1)
  end
end
