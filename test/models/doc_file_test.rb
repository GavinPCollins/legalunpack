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

  test "files are active by default and can be archived" do
    active_doc_file = create_doc_file(extraction_status: "complete", extracted_text: "Current file.")
    archived_doc_file = create_doc_file(extraction_status: "complete", extracted_text: "Old file.")
    archived_doc_file.update!(archived_at: Time.current)

    assert active_doc_file.active?
    assert_not archived_doc_file.active?
    assert_equal [ active_doc_file ], @package.doc_files.active.to_a
    assert_equal [ archived_doc_file ], @package.doc_files.archived.to_a
  end

  test "archived file can reference an active replacement in the same package" do
    archived_doc_file = create_doc_file(extraction_status: "complete", extracted_text: "Old file.")
    replacement = create_doc_file(extraction_status: "complete", extracted_text: "Replacement file.")

    assert archived_doc_file.update(archived_at: Time.current, replaced_by_doc_file: replacement)
    assert_equal replacement, archived_doc_file.replaced_by_doc_file
    assert_includes replacement.replaced_doc_files, archived_doc_file
  end

  test "replacement must be a different active file in the same package" do
    archived_doc_file = create_doc_file(extraction_status: "complete", extracted_text: "Old file.")
    archived_doc_file.archived_at = Time.current
    archived_doc_file.replaced_by_doc_file = archived_doc_file

    assert_not archived_doc_file.valid?
    assert_includes archived_doc_file.errors[:replaced_by_doc_file], "cannot be the same file"

    other_user = User.create!(email: "replacement@example.com", password: "password", username: "replacement")
    other_package = other_user.packages.create!(name: "Other package")
    other_file = other_package.doc_files.create!(
      file: {
        io: StringIO.new("Other file."),
        filename: "other.txt",
        content_type: "text/plain"
      }
    )
    archived_doc_file.replaced_by_doc_file = other_file

    assert_not archived_doc_file.valid?
    assert_includes archived_doc_file.errors[:replaced_by_doc_file], "must belong to the same package"

    archived_replacement = create_doc_file(extraction_status: "complete", extracted_text: "Archived replacement.")
    archived_replacement.update!(archived_at: Time.current)
    archived_doc_file.replaced_by_doc_file = archived_replacement

    assert_not archived_doc_file.valid?
    assert_includes archived_doc_file.errors[:replaced_by_doc_file], "must be active"
  end

  test "replacement cannot create a circular chain" do
    first_file = create_doc_file(extraction_status: "complete", extracted_text: "First file.")
    second_file = create_doc_file(extraction_status: "complete", extracted_text: "Second file.")
    first_file.update!(archived_at: Time.current, replaced_by_doc_file: second_file)
    second_file.archived_at = Time.current
    second_file.replaced_by_doc_file = first_file

    assert_not second_file.valid?
    assert_includes second_file.errors[:replaced_by_doc_file], "would create a circular replacement chain"
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

  test "provides readable analysis progress labels" do
    doc_file = @package.doc_files.build(
      analysis_stage: "checking_sources",
      analysis_position: 2,
      analysis_total: 3
    )

    assert_equal "Checking relevant sources", doc_file.analysis_progress_label
    assert_equal "Analyzing file 2 of 3", doc_file.analysis_batch_label
  end

  test "ready for ai includes only complete files with extracted text" do
    ready_doc_file = create_doc_file(extraction_status: "complete", extracted_text: "Ready text.")
    create_doc_file(extraction_status: "pending", extracted_text: "Pending text.")
    create_doc_file(extraction_status: "failed", extracted_text: "Failed text.")
    create_doc_file(extraction_status: "complete", extracted_text: nil)
    create_doc_file(extraction_status: "complete", extracted_text: "")

    assert_equal [ ready_doc_file ], @package.doc_files.ready_for_ai.to_a
  end

  test "ready for ai skips files with complete ai analysis" do
    create_doc_file(extraction_status: "complete", extracted_text: "Already analyzed.", ai_status: "complete")
    retryable_doc_file = create_doc_file(extraction_status: "complete", extracted_text: "Retry this.", ai_status: "failed")

    assert_equal [ retryable_doc_file ], @package.doc_files.ready_for_ai.to_a
  end

  test "processing error message extracts api message from stored response body" do
    error_message = "Request body too large for gpt-4.1-mini model. Max size: 8000 tokens."
    doc_file = create_doc_file(
      extraction_status: "complete",
      extracted_text: "Too much text.",
      ai_status: "failed"
    )
    doc_file.update!(ai_error: %(GitHub Models request failed: 413 {"message":"#{error_message}"}))

    assert_equal error_message, doc_file.processing_error_message
  end

  test "processing error message extracts nested api error message from stored response body" do
    error_message = "Request body too large for gpt-4.1-mini model. Max size: 8000 tokens."
    doc_file = create_doc_file(
      extraction_status: "complete",
      extracted_text: "Too much text.",
      ai_status: "failed"
    )
    error_payload = {
      error: {
        code: "tokens_limit_reached",
        message: error_message,
        details: error_message
      }
    }
    doc_file.update!(
      ai_error: "GitHub Models request failed: 413 #{error_payload.to_json}"
    )

    assert_equal error_message, doc_file.processing_error_message
  end

  test "processing error message falls back to stored extraction error" do
    doc_file = create_doc_file(
      extraction_status: "failed",
      extracted_text: nil,
      ai_status: "pending"
    )
    doc_file.update!(extraction_error: "Zip end of central directory signature not found")

    assert_equal "Zip end of central directory signature not found", doc_file.processing_error_message
  end

  test "needs text extraction includes old files with nil extraction status" do
    old_doc_file = create_doc_file(extraction_status: "pending", extracted_text: nil)
    old_doc_file.update_column(:extraction_status, nil)

    assert_includes @package.doc_files.needs_text_extraction, old_doc_file
  end

  private

  def create_doc_file(extraction_status:, extracted_text:, ai_status: "pending")
    @package.doc_files.create!(
      extraction_status: extraction_status,
      extracted_text: extracted_text,
      ai_status: ai_status,
      file: {
        io: StringIO.new("Sample legal text."),
        filename: "#{extraction_status}-#{@package.doc_files.count}.txt",
        content_type: "text/plain"
      }
    )
  end
end
