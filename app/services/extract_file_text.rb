class ExtractFileText
  def self.call(doc_file)
    new(doc_file).call
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
end
