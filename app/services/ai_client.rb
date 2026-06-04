require "json"
require "net/http"
require "uri"

# Low-level wrapper for sending text to GitHub Models and returning the response text.
class AiClient
  DEFAULT_ENDPOINT = "https://models.github.ai/inference/chat/completions"
  DEFAULT_MODEL = "openai/gpt-4.1"

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
    response_body = @client ? @client.call(request_parameters(input)) : perform_request(input)
    response = JSON.parse(response_body)

    # Extract only the assistant's message text from the API response.
    response.dig("choices", 0, "message", "content")
  end

  private

  def perform_request(input)
    uri = URI(ENV.fetch("GITHUB_MODELS_ENDPOINT", DEFAULT_ENDPOINT))
    request = Net::HTTP::Post.new(uri)
    request["Accept"] = "application/vnd.github+json"
    request["Authorization"] = "Bearer #{github_token}"
    request["Content-Type"] = "application/json"
    request["X-GitHub-Api-Version"] = "2026-03-10"
    request.body = request_parameters(input).to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    raise "GitHub Models request failed: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  # Allow model override through an argument or env var.
  def model
    @model || ENV["GITHUB_MODEL"].presence || ENV["OPENAI_MODEL"].presence || DEFAULT_MODEL
  end

  def github_token
    ENV["GITHUB_MODELS_TOKEN"].presence || ENV.fetch("GITHUB_TOKEN")
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
