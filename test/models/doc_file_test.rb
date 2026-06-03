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
end
