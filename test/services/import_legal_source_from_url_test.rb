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

  FakeRedirectResponse = Struct.new(:location, :code, :message, keyword_init: true) do
    def [](key)
      return location if key == "Location"
    end

    def is_a?(klass)
      klass == Net::HTTPRedirection || super
    end
  end

  FakeHttpClient = Struct.new(:responses, keyword_init: true) do
    def get_response(_uri)
      responses.shift
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

    ImportLegalSourceFromUrl.call(legal_source, http_client: FakeHttpClient.new(responses: [ response ]))

    legal_source.reload
    assert_equal "html", legal_source.source_format
    assert legal_source.raw_text.include?("Major problems")
    assert_not legal_source.raw_text.include?("Navigation should not be imported")
    assert_equal 1, legal_source.legal_source_chunks.count
    assert legal_source.legal_source_chunks.first.content.include?("Consumers may be entitled")
  end

  test "follows redirects when importing url sources" do
    legal_source = LegalSource.create!(
      title: "Refunds and returns",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      publisher: "Consumer Affairs Victoria",
      source_url: "https://www.consumer.vic.gov.au/old-refunds",
      source_format: "html"
    )
    redirect = FakeRedirectResponse.new(
      location: "https://www.consumer.vic.gov.au/refunds",
      code: "302",
      message: "Found"
    )
    final_response = FakeResponse.new(
      body: <<~HTML,
        <html>
          <body>
            <h1>Refunds and returns</h1>
            <p>Consumers may be entitled to a refund when goods have a major problem.</p>
            <p>This imported page came from a redirected legal source URL.</p>
          </body>
        </html>
      HTML
      code: "200",
      message: "OK"
    )

    ImportLegalSourceFromUrl.call(
      legal_source,
      http_client: FakeHttpClient.new(responses: [ redirect, final_response ])
    )

    legal_source.reload
    assert_includes legal_source.raw_text, "redirected legal source URL"
    assert_equal 1, legal_source.legal_source_chunks.count
  end

  test "imports text from an attached source file into chunks" do
    legal_source = LegalSource.create!(
      title: "Uploaded guidance",
      jurisdiction: "VIC",
      source_type: "regulator_guidance",
      authority_level: "guidance",
      source_format: "txt",
      source_file: Rack::Test::UploadedFile.new(
        Rails.root.join("test/fixtures/files/sample.txt"),
        "text/plain"
      )
    )

    ImportLegalSourceFromUrl.call(legal_source)

    assert_equal "Sample legal text.", legal_source.reload.raw_text
    assert legal_source.imported?
    assert_equal 1, legal_source.legal_source_chunks.count
    assert_equal "Sample legal text.", legal_source.legal_source_chunks.first.content
  end
end
