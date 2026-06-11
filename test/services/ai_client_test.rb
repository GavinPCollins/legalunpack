require "test_helper"

class AiClientTest < ActiveSupport::TestCase
  test "returns message content from the AI response" do
    fake_client = FakeGitHubModelsClient.new("Hello from AI.")

    response = AiClient.call("Reply with a greeting.", client: fake_client, model: "test-model")

    assert_equal "Hello from AI.", response
    assert_equal "test-model", fake_client.parameters[:model]
    assert_equal [ { role: "user", content: "Reply with a greeting." } ], fake_client.parameters[:messages]
  end

  test "can request a json response" do
    fake_client = FakeGitHubModelsClient.new('{ "status": "ok" }')

    response = AiClient.call("Return JSON.", client: fake_client, json_response: true)

    assert_equal '{ "status": "ok" }', response
    assert_equal({ type: "json_object" }, fake_client.parameters[:response_format])
  end

  test "requires input" do
    assert_raises ArgumentError do
      AiClient.call("", client: FakeGitHubModelsClient.new("unused"))
    end
  end

  test "rejects malformed response json" do
    error = assert_raises RuntimeError do
      AiClient.call("Reply with a greeting.", client: RawGitHubModelsClient.new("not json"))
    end

    assert_equal AiClient::INVALID_RESPONSE_MESSAGE, error.message
  end

  test "rejects response without assistant content" do
    error = assert_raises RuntimeError do
      AiClient.call("Reply with a greeting.", client: RawGitHubModelsClient.new({ choices: [] }.to_json))
    end

    assert_equal AiClient::INVALID_RESPONSE_MESSAGE, error.message
  end

  test "rejects valid json with an unexpected shape" do
    error = assert_raises RuntimeError do
      AiClient.call("Reply with a greeting.", client: RawGitHubModelsClient.new([].to_json))
    end

    assert_equal AiClient::INVALID_RESPONSE_MESSAGE, error.message
  end

  test "rejects blank assistant content" do
    error = assert_raises RuntimeError do
      AiClient.call("Reply with a greeting.", client: FakeGitHubModelsClient.new("  "))
    end

    assert_equal AiClient::INVALID_RESPONSE_MESSAGE, error.message
  end

  test "uses bounded http timeouts" do
    options = AiClient.new.send(:http_options, URI("https://models.github.ai"))

    assert_equal true, options[:use_ssl]
    assert_equal AiClient::DEFAULT_OPEN_TIMEOUT, options[:open_timeout]
    assert_equal AiClient::DEFAULT_READ_TIMEOUT, options[:read_timeout]
  end

  test "uses response message for github model errors" do
    response = Struct.new(:code, :body).new(
      "413",
      { message: "Request body too large for gpt-4.1-mini model. Max size: 8000 tokens." }.to_json
    )

    error_message = AiClient.new.send(:github_models_error_message, response)

    assert_equal "Request body too large for gpt-4.1-mini model. Max size: 8000 tokens.", error_message
  end

  test "uses nested response message for github model errors" do
    response = Struct.new(:code, :body).new(
      "413",
      {
        error: {
          code: "tokens_limit_reached",
          message: "Request body too large for gpt-4.1-mini model. Max size: 8000 tokens."
        }
      }.to_json
    )

    error_message = AiClient.new.send(:github_models_error_message, response)

    assert_equal "Request body too large for gpt-4.1-mini model. Max size: 8000 tokens.", error_message
  end

  class FakeGitHubModelsClient
    attr_reader :parameters

    def initialize(content)
      @content = content
    end

    def call(parameters)
      @parameters = parameters
      {
        "choices" => [
          {
            "message" => {
              "content" => @content
            }
          }
        ]
      }.to_json
    end
  end

  RawGitHubModelsClient = Struct.new(:response_body) do
    def call(_parameters)
      response_body
    end
  end
end
