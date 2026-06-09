require "test_helper"

class ImportLegalSourceFromUrlTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:body, :code, :message, keyword_init: true) do
    def [](key)
      return "text/html" if key == "Content-Type"
    end

    def is_a?(klass)
      klass == Net::HTTPSuccess || super
    end
  end

  FakeHttpClient = Struct.new(:response, keyword_init: true) do
    def get_response(_uri)
      response
    end
  end

  test "imports html legal source text into chunks" do
    legal_source = LegalSource.create!(
      title: "Refunds and returns",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      publisher: "Consumer Affairs Victoria",
      source_url: "https://www.consumer.vic.gov.au/refunds",
      source_format: "html"
    )
    html = <<~HTML
      <html>
        <body>
          <nav>Navigation should not be imported.</nav>
          <h1>Refunds and returns</h1>
          <h2>Major problems</h2>
          <p>Consumers may be entitled to a refund when goods have a major problem.</p>
          <p>This guidance explains practical consumer rights in Victoria.</p>
          <h2>Minor problems</h2>
          <p>Businesses can usually choose whether to repair, replace or refund for minor problems.</p>
          <p>The appropriate remedy depends on the circumstances.</p>
        </body>
      </html>
    HTML
    response = FakeResponse.new(body: html, code: "200", message: "OK")

    ImportLegalSourceFromUrl.call(legal_source, http_client: FakeHttpClient.new(response: response))

    legal_source.reload
    assert_equal "html", legal_source.source_format
    assert legal_source.raw_text.include?("Major problems")
    assert_not legal_source.raw_text.include?("Navigation should not be imported")
    assert_equal 1, legal_source.legal_source_chunks.count
    assert legal_source.legal_source_chunks.first.content.include?("Consumers may be entitled")
  end
end
