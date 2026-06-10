require "net/http"
require "nokogiri"
require "open3"
require "pathname"
require "pdf/reader"
require "stringio"
require "tmpdir"
require "uri"

class ImportLegalSourceFromUrl
  DEFAULT_CHUNK_SIZE = 3_000
  DEFAULT_CHUNK_OVERLAP = 300
  MAX_REDIRECTS = 5
  OCR_RESOLUTION = 200

  def self.call(legal_source, http_client: Net::HTTP)
    new(legal_source, http_client: http_client).call
  end

  def initialize(legal_source, http_client: Net::HTTP)
    @legal_source = legal_source
    @http_client = http_client
  end

  def call
    source = read_source
    format = detected_format(source)
    raw_text = extract_text(source.body, format)
    chunks = chunk_text(raw_text)

    raise "No readable text found for #{source.label}" if raw_text.blank?
    raise "No chunks created for #{source.label}" if chunks.blank?

    LegalSource.transaction do
      legal_source.update!(
        source_format: format,
        raw_text: raw_text,
        imported_at: Time.current
      )

      legal_source.legal_source_chunks.destroy_all

      chunks.each.with_index(1) do |chunk, position|
        legal_source.legal_source_chunks.create!(
          section_label: chunk[:section_label],
          heading: chunk[:heading],
          content: chunk[:content],
          position: position
        )
      end
    end

    legal_source
  end

  private

  attr_reader :legal_source, :http_client

  SourceResponse = Struct.new(:body, :content_type, :path, :label, keyword_init: true)

  def read_source
    return read_attached_source if legal_source.source_file.attached?
    return read_local_source if local_source?

    fetch_url(URI.parse(legal_source.source_url))
  end

  def read_attached_source
    blob = legal_source.source_file.blob

    SourceResponse.new(
      body: legal_source.source_file.download,
      content_type: blob.content_type,
      path: blob.filename.to_s,
      label: blob.filename.to_s
    )
  end

  def fetch_url(uri, redirect_count = 0)
    response = http_client.get_response(uri)

    if response.is_a?(Net::HTTPRedirection)
      raise "Too many redirects for #{legal_source.source_url}" if redirect_count >= MAX_REDIRECTS

      location = response["Location"].to_s
      raise "Redirect response missing Location header for #{legal_source.source_url}" if location.blank?

      return fetch_url(URI.join(uri, location), redirect_count + 1)
    end

    raise "Legal source import failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    SourceResponse.new(
      body: response.body,
      content_type: response["Content-Type"].to_s,
      path: uri.path,
      label: legal_source.source_url
    )
  end

  def read_local_source
    path = Pathname.new(legal_source.source_url)
    raise "Local legal source file does not exist: #{path}" unless path.file?

    SourceResponse.new(
      body: path.binread,
      content_type: nil,
      path: path.to_s,
      label: path.to_s
    )
  end

  def local_source?
    return false if legal_source.source_url.blank?

    uri = URI.parse(legal_source.source_url)
    uri.scheme.blank?
  rescue URI::InvalidURIError
    true
  end

  def detected_format(source)
    content_type = source.content_type.to_s.downcase
    path = source.path.to_s.downcase

    return "pdf" if content_type.include?("pdf") || path.end_with?(".pdf")
    return "txt" if content_type.include?("text/plain") || path.end_with?(".txt")

    "html"
  end

  def extract_text(body, format)
    case format
    when "pdf"
      extract_pdf_text(body)
    when "txt"
      body.to_s
    else
      extract_html_text(body)
    end.then { |text| normalize_text(text) }
  end

  def extract_pdf_text(body)
    text = extract_pdf_text_with_reader(body)
    return text if text.present?

    extract_pdf_text_with_ocr(body)
  end

  def extract_pdf_text_with_reader(body)
    PDF::Reader.new(StringIO.new(body)).pages.map(&:text).join("\n\n")
  rescue PDF::Reader::Error => error
    Rails.logger.warn("PDF text extraction failed for #{legal_source.source_name}: #{error.message}")
    nil
  end

  def extract_pdf_text_with_ocr(body)
    begin
      require "rtesseract"
    rescue LoadError
      raise "OCR fallback requires the rtesseract gem, Ghostscript, and Tesseract to be installed"
    end

    Dir.mktmpdir("legal-source-ocr") do |directory|
      render_pdf_pages_for_ocr(body, directory).map do |image_path|
        ocr_image(image_path)
      end.join("\n\n")
    end
  rescue Errno::ENOENT
    raise "OCR fallback requires Ghostscript and Tesseract to be installed"
  rescue StandardError => error
    raise if error.message.start_with?("OCR fallback requires")

    raise "OCR fallback failed for #{legal_source.source_name}: #{error.message}"
  end

  def render_pdf_pages_for_ocr(body, directory)
    pdf_path = File.join(directory, "source.pdf")
    output_pattern = File.join(directory, "page-%04d.png")
    File.binwrite(pdf_path, body)

    stdout, stderr, status = Open3.capture3(
      "gs",
      "-q",
      "-dNOPAUSE",
      "-dBATCH",
      "-sDEVICE=pnggray",
      "-r#{OCR_RESOLUTION}",
      "-sOutputFile=#{output_pattern}",
      pdf_path
    )

    raise "OCR PDF rendering failed for #{legal_source.source_name}: #{stderr.presence || stdout}" unless status.success?

    Dir.glob(File.join(directory, "page-*.png")).sort
  end

  def ocr_image(image_path)
    RTesseract.new(image_path, lang: ENV.fetch("TESSERACT_LANG", "eng")).to_s
  end

  def extract_html_text(body)
    document = Nokogiri::HTML(body)
    document.css("script, style, noscript, svg, nav, footer").remove

    document.css("h1, h2, h3, h4, p, li").map do |node|
      node.text.squish
    end.reject(&:blank?).join("\n\n")
  end

  def normalize_text(text)
    text.to_s
      .gsub(/\r\n?/, "\n")
      .gsub(/[ \t]+/, " ")
      .gsub(/\n{3,}/, "\n\n")
      .strip
  end

  def chunk_text(raw_text)
    section_chunks = chunk_by_sections(raw_text)
    return section_chunks if section_chunks.size > 1

    chunk_by_size(raw_text)
  end

  def chunk_by_sections(raw_text)
    chunks = []
    current_heading = nil
    current_lines = []

    raw_text.each_line do |line|
      line = line.strip
      next if line.blank?

      if legal_heading?(line)
        chunks << build_chunk(current_heading, current_lines.join("\n")) if current_lines.present?
        current_heading = line
        current_lines = [ line ]
      else
        current_lines << line
      end
    end

    chunks << build_chunk(current_heading, current_lines.join("\n")) if current_lines.present?
    chunks.select { |chunk| chunk[:content].length >= 120 }
  end

  def legal_heading?(line)
    return false if line.length > 180

    line.match?(/\A(?:section|s|regulation|reg|clause|part|division|schedule)\s+\d+[a-z]?\b/i) ||
      line.match?(/\A\d+[A-Z]?\s+[A-Z][^\n]{3,}\z/) ||
      line.match?(/\A[A-Z][A-Z\s,()'\/-]{8,}\z/)
  end

  def build_chunk(heading, content)
    {
      section_label: section_label_from(heading),
      heading: heading,
      content: content.truncate(6_000, separator: "\n")
    }
  end

  def section_label_from(heading)
    heading.to_s.match(/\A((?:section|s|regulation|reg|clause|part|division|schedule)\s+\d+[a-z]?)/i)&.[](1)
  end

  def chunk_by_size(raw_text)
    chunks = []
    index = 0

    while index < raw_text.length
      content = raw_text[index, DEFAULT_CHUNK_SIZE].to_s
      break if content.blank?

      chunks << {
        section_label: nil,
        heading: nil,
        content: content.strip
      }

      index += DEFAULT_CHUNK_SIZE - DEFAULT_CHUNK_OVERLAP
    end

    chunks
  end
end
