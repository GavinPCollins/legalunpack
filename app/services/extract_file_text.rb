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

  def call
    file = @doc_file.file

    case file.content_type
    when "text/plain"
      file.download
    else
      raise "Unsupported file type: #{file.content_type}"
    end
  end

  def save!
    @doc_file.update!(extraction_status: "processing")

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
end
