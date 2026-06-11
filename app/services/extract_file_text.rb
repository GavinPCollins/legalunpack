require "pdf/reader"
require "docx"

# EXTRACT FILE TEXT
class ExtractFileText
  def self.call(doc_file)
    new(doc_file).call
  end

  def self.save!(doc_file)
    new(doc_file).save!
  end

  def initialize(doc_file)
    @doc_file = doc_file
  end

  # RETURN EXTRACTED TEXT
  def call
    file = @doc_file.file

    text =
      case file.content_type
      when "text/plain"
        file.download
      when "application/pdf"
        extract_pdf(file.download)
      when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        extract_docx(file.download)
      when "application/rtf", "application/x-rtf", "text/rtf"
        extract_rtf(file.download)
      else
        raise "Unsupported file type: #{file.content_type}"
      end

    normalize_text(text)
  end

  # SAVE EXTRACTED TEXT
  def save!
    attributes = { extraction_status: "processing" }
    attributes[:analysis_stage] = "extracting_text" if @doc_file.ai_status == "processing"
    @doc_file.update!(attributes)

    text = call

    @doc_file.update!(
      extracted_text: text,
      extraction_status: "complete",
      extraction_error: nil,
      extracted_at: Time.current
    )
  rescue StandardError => error
    @doc_file.update!(
      extraction_status: "failed",
      extraction_error: error.message,
      extracted_at: nil
    )

    raise
  end

  private

  # EXTRACT PDF
  def extract_pdf(bytes)
    reader = PDF::Reader.new(StringIO.new(bytes))

    reader.pages.map(&:text).join("\n\n")
  end

  # EXTRACT DOCX
  def extract_docx(bytes)
    tempfile = Tempfile.new(["docx-upload", ".docx"])
    tempfile.binmode
    tempfile.write(bytes)
    tempfile.rewind

    document = Docx::Document.open(tempfile.path)
    document.paragraphs.map(&:text).join("\n")
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  # EXTRACT RTF
  def extract_rtf(bytes)
    bytes
      .gsub(/\\'[0-9a-fA-F]{2}/, "")
      .gsub(/\\[a-zA-Z]+\d* ?/, "")
      .gsub(/[{}]/, "")
      .gsub(/\r\n?/, "\n")
      .strip
  end

  # NORMALIZE TEXT
  def normalize_text(text)
    text
      .gsub(/\r\n?/, "\n")
      .gsub(/[ \t]+/, " ")
      .gsub(/\n{3,}/, "\n\n")
      .strip
  end
end
