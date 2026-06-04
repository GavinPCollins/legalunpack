require "test_helper"

class AiClientTest < ActiveSupport::TestCase
  test "returns message content from the AI response" do
    fake_client = FakeOpenAiClient.new("Hello from AI.")

    response = AiClient.call("Reply with a greeting.", client: fake_client, model: "test-model")

    assert_equal "Hello from AI.", response
    assert_equal "test-model", fake_client.parameters[:model]
    assert_equal [ { role: "user", content: "Reply with a greeting." } ], fake_client.parameters[:messages]
  end

  test "can request a json response" do
    fake_client = FakeOpenAiClient.new('{ "status": "ok" }')

    response = AiClient.call("Return JSON.", client: fake_client, json_response: true)

    assert_equal '{ "status": "ok" }', response
    assert_equal({ type: "json_object" }, fake_client.parameters[:response_format])
  end

  test "requires input" do
    assert_raises ArgumentError do
      AiClient.call("", client: FakeOpenAiClient.new("unused"))
    end
  end

  class FakeOpenAiClient
    attr_reader :parameters

    def initialize(content)
      @content = content
    end

    def chat(parameters:)
      @parameters = parameters
      {
        "choices" => [
          {
            "message" => {
              "content" => @content
            }
          }
        ]
      }
    end
  end
end
