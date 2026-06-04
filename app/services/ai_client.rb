# Low-level wrapper for sending text to OpenAI and returning the response text.
class AiClient
  DEFAULT_MODEL = "gpt-4o-mini"

  # Public entrypoint: AiClient.call("Your prompt text")
  def self.call(input, client: nil, model: nil, json_response: false)
    new(client: client, model: model, json_response: json_response).call(input)
  end

  def initialize(client: nil, model: nil, json_response: false)
    @client = client
    @model = model
    @json_response = json_response
  end

  def call(input)
    raise ArgumentError, "input must be present" if input.blank?

    # Send one user message to the chat model.
    response = client.chat(
      parameters: request_parameters(input)
    )

    # Extract only the assistant's message text from the API response.
    response.dig("choices", 0, "message", "content")
  end

  private

  # Build the real OpenAI client unless a fake client was supplied for tests.
  def client
    @client ||= OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
  end

  # Allow model override through an argument or OPENAI_MODEL.
  def model
    @model || ENV.fetch("OPENAI_MODEL", DEFAULT_MODEL)
  end

  def request_parameters(input)
    parameters = {
      model: model,
      messages: [
        { role: "user", content: input }
      ]
    }

    # Ask the model for a JSON object when the caller needs parseable output.
    parameters[:response_format] = { type: "json_object" } if @json_response

    parameters
  end
end
