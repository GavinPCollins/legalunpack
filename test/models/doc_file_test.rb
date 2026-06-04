require "test_helper"

class DocFileTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "doc-file@example.com", password: "password", username: "docfile")
    @package = user.packages.create!(name: "Lease review")
  end

  test "allows supported legal document files" do
    doc_file = @package.doc_files.build
    doc_file.file.attach(
      io: StringIO.new("Sample legal text."),
      filename: "sample.txt",
      content_type: "text/plain"
    )

    assert doc_file.valid?
  end

  test "rejects unsupported file types" do
    doc_file = @package.doc_files.build
    doc_file.file.attach(
      io: StringIO.new("<script>alert('nope')</script>"),
      filename: "sample.html",
      content_type: "text/html"
    )

    assert_not doc_file.valid?
    assert_includes doc_file.errors[:file], "must be a PDF, DOCX, TXT, or RTF file"
  end

  test "rejects files over the size limit" do
    doc_file = @package.doc_files.build
    doc_file.file.attach(
      io: StringIO.new("Sample legal text."),
      filename: "sample.txt",
      content_type: "text/plain"
    )
    doc_file.file.blob.define_singleton_method(:byte_size) { DocFile::MAX_FILE_SIZE + 1 }

    assert_not doc_file.valid?
    assert_includes doc_file.errors[:file], "must be smaller than 25 MB"
  end

  test "defaults extraction status to pending" do
    doc_file = @package.doc_files.build

    assert_equal "pending", doc_file.extraction_status
  end

  test "defaults ai status to pending" do
    doc_file = @package.doc_files.build

    assert_equal "pending", doc_file.ai_status
  end

  test "ai status must be valid" do
    doc_file = @package.doc_files.build(ai_status: "queued")
    doc_file.file.attach(
      io: StringIO.new("Sample legal text."),
      filename: "sample.txt",
      content_type: "text/plain"
    )

    assert_not doc_file.valid?
    assert_includes doc_file.errors[:ai_status], "is not included in the list"
  end

  test "ready for ai includes only complete files with extracted text" do
    ready_doc_file = create_doc_file(extraction_status: "complete", extracted_text: "Ready text.")
    create_doc_file(extraction_status: "pending", extracted_text: "Pending text.")
    create_doc_file(extraction_status: "failed", extracted_text: "Failed text.")
    create_doc_file(extraction_status: "complete", extracted_text: nil)
    create_doc_file(extraction_status: "complete", extracted_text: "")

    assert_equal [ ready_doc_file ], @package.doc_files.ready_for_ai.to_a
  end

  private

  def create_doc_file(extraction_status:, extracted_text:)
    @package.doc_files.create!(
      extraction_status: extraction_status,
      extracted_text: extracted_text,
      file: {
        io: StringIO.new("Sample legal text."),
        filename: "#{extraction_status}-#{@package.doc_files.count}.txt",
        content_type: "text/plain"
      }
    )
  end
end
