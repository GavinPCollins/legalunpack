require "test_helper"

class ExtractFileTextTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "extract@example.com", password: "password", username: "extract")
    package = user.packages.create!(name: "Lease review")

    @doc_file = package.doc_files.create!(
      file: {
        io: StringIO.new("Sample legal text."),
        filename: "sample.txt",
        content_type: "text/plain"
      }
    )
  end

  test "extracts text from a plain text file" do
    assert_equal "Sample legal text.", ExtractFileText.call(@doc_file)
  end

  test "saves extracted text and marks extraction complete" do
    ExtractFileText.save!(@doc_file)

    @doc_file.reload

    assert_equal "Sample legal text.", @doc_file.extracted_text
    assert_equal "complete", @doc_file.extraction_status
    assert_nil @doc_file.extraction_error
    assert_not_nil @doc_file.extracted_at
  end

  test "marks extraction failed when extraction is unsupported" do
    @doc_file.file.attach(
      io: StringIO.new("%PDF-1.4 fake pdf"),
      filename: "sample.pdf",
      content_type: "application/pdf"
    )
  
    assert_raises RuntimeError do
      ExtractFileText.save!(@doc_file)
    end
  
    @doc_file.reload
  
    assert_equal "failed", @doc_file.extraction_status
    assert_equal "Unsupported file type: application/pdf", @doc_file.extraction_error
    assert_nil @doc_file.extracted_at
  end
end
