class ChatbotSessionsController < ApplicationController
  # POST /packages/:package_id/chatbot_sessions
  def create
    package = current_user.packages.find(params[:package_id])

    question = params[:question].to_s.strip
    target = params[:target].to_s.presence || "package"
    target_id = params[:target_id]

    return render json: { error: "Question can't be blank" }, status: :unprocessable_entity if question.blank?

    prompt = ChatbotPromptBuilder.build(package, question: question, target: target, target_id: target_id)

    ActiveRecord::Base.transaction do
      package.chat_messages.create!(user: current_user, role: "user", content: question)

      answer = AiClient.call(prompt)

      package.chat_messages.create!(user: current_user, role: "assistant", content: answer)

      # Parse out an optional "External analysis" section if the model provides it.
      external_section_regex = /\A(.*?)(?:\r?\n)?^\s*External analysis[:\s]*\r?\n(.*)\z/im
      if (m = answer.match(external_section_regex))
        document_answer = m[1].to_s.strip
        external_text = m[2].to_s.strip

        confidence = if (c = external_text.match(/confidence\s*[:-]\s*(high|medium|low)/i))
                       c[1].downcase
                     end

        render json: {
          answer: document_answer.presence || nil,
          external_analysis: external_text.presence || nil,
          external_confidence: confidence
        }
      else
        render json: { answer: answer }
      end
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
