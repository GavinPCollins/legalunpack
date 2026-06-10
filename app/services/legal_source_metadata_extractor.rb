require "json"
require "nokogiri"
require "pdf/reader"
require "stringio"

class LegalSourceMetadataExtractor
  MAX_TEXT_LENGTH = 10_000

  def self.call(uploaded_file, ai_client: AiClient)
    new(uploaded_file, ai_client: ai_client).call
  end

  def initialize(uploaded_file, ai_client: AiClient)
    @uploaded_file = uploaded_file
    @ai_client = ai_client
  end

  def call
    extracted_text = extract_text
    raise "No readable text found for autofill" if extracted_text.blank?

    JSON.parse(ai_client.call(prompt(extracted_text), json_response: true)).slice(
      "title",
      "citation",
      "jurisdiction",
      "source_type",
      "authority_level",
      "publisher",
      "source_format"
    ).compact_blank
  end

  private

  attr_reader :uploaded_file, :ai_client

  def extract_text
    text = case content_type
           when "application/pdf"
             extract_pdf
           when "text/html"
             extract_html
           else
             uploaded_file.read.to_s
           end

    normalize_text(text).truncate(MAX_TEXT_LENGTH, separator: "\n\n")
  ensure
    uploaded_file.rewind if uploaded_file.respond_to?(:rewind)
  end

  def content_type
    uploaded_file.content_type.to_s
  end

  def extract_pdf
    PDF::Reader.new(StringIO.new(uploaded_file.read)).pages.first(10).map(&:text).join("\n\n")
  end

  def extract_html
    document = Nokogiri::HTML(uploaded_file.read)
    document.css("script, style, noscript, svg, nav, footer").remove
    document.css("h1, h2, h3, h4, p, li").map { |node| node.text.squish }.reject(&:blank?).join("\n\n")
  end

  def normalize_text(text)
    text.to_s
      .gsub(/\r\n?/, "\n")
      .gsub(/[ \t]+/, " ")
      .gsub(/\n{3,}/, "\n\n")
      .strip
  end

  def prompt(extracted_text)
    <<~PROMPT
      Extract legal source metadata from the uploaded resource text.

      Return ONLY a JSON object with these keys:
      - title: official source name, or null if unclear
      - citation: formal citation/version/authorised version, or null if unclear
      - jurisdiction: short jurisdiction code such as VIC, NSW, CTH, or null if unclear
      - source_type: one of #{LegalSource::SOURCE_TYPES.join(", ")}
      - authority_level: one of #{LegalSource::AUTHORITY_LEVELS.join(", ")}
      - publisher: official publisher/regulator/parliament, or null if unclear
      - source_format: one of #{LegalSource::SOURCE_FORMATS.join(", ")}

      Prefer exact text from the source. Do not invent metadata. If unsure, use null.

      Filename: #{uploaded_file.original_filename}
      Content type: #{content_type}

      Source text:
      #{extracted_text}
    PROMPT
  end
end
