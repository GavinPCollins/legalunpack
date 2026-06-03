require "test_helper"

class PackageTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "package@example.com", password: "password", username: "package")
    @package = user.packages.create!(name: "Lease review")
  end

  test "extraction is complete when every file is complete" do
    create_doc_file(extraction_status: "complete")
    create_doc_file(extraction_status: "complete")

    assert @package.extraction_complete?
    assert_not @package.extraction_failed?
    assert_not @package.extraction_in_progress?
  end

  test "extraction is failed when any file failed" do
    create_doc_file(extraction_status: "complete")
    create_doc_file(extraction_status: "failed")

    assert_not @package.extraction_complete?
    assert @package.extraction_failed?
  end

  test "extraction is in progress when any file is pending or processing" do
    create_doc_file(extraction_status: "pending")
    create_doc_file(extraction_status: "processing")

    assert_not @package.extraction_complete?
    assert @package.extraction_in_progress?
  end

  test "extraction is not complete for a package without files" do
    assert_not @package.extraction_complete?
    assert_not @package.extraction_failed?
    assert_not @package.extraction_in_progress?
  end

  test "formats completed extracted text for ai" do
    create_doc_file(
      extraction_status: "complete",
      extracted_text: "First extracted text.",
      filename: "first.txt"
    )
    create_doc_file(
      extraction_status: "complete",
      extracted_text: "Second extracted text.",
      filename: "second.txt"
    )

    assert_equal <<~TEXT.strip, @package.extracted_text_for_ai
      File: first.txt

      First extracted text.

      ---

      File: second.txt

      Second extracted text.
    TEXT
  end

  test "excludes files that are not ready for ai" do
    create_doc_file(extraction_status: "complete", extracted_text: "Ready text.", filename: "ready.txt")
    create_doc_file(extraction_status: "pending", extracted_text: "Pending text.", filename: "pending.txt")
    create_doc_file(extraction_status: "failed", extracted_text: "Failed text.", filename: "failed.txt")
    create_doc_file(extraction_status: "complete", extracted_text: nil, filename: "empty.txt")

    text = @package.extracted_text_for_ai

    assert_includes text, "Ready text."
    assert_no_match(/Pending text./, text)
    assert_no_match(/Failed text./, text)
    assert_no_match(/empty.txt/, text)
  end

  private

  def create_doc_file(extraction_status:, extracted_text: "Sample legal text.", filename: "#{extraction_status}.txt")
    @package.doc_files.create!(
      extraction_status: extraction_status,
      extracted_text: extracted_text,
      file: {
        io: StringIO.new("Sample legal text."),
        filename: filename,
        content_type: "text/plain"
      }
    )
  end
end
