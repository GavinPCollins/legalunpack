require "test_helper"

class ExtractPackageTextJobTest < ActiveJob::TestCase
  setup do
    user = User.create!(email: "job@example.com", password: "password", username: "job")
    @package = user.packages.create!(name: "Lease review")

    @first_doc_file = @package.doc_files.create!(
      file: {
        io: StringIO.new("First legal text."),
        filename: "first.txt",
        content_type: "text/plain"
      }
    )

    @second_doc_file = @package.doc_files.create!(
      file: {
        io: StringIO.new("Second legal text."),
        filename: "second.txt",
        content_type: "text/plain"
      }
    )
  end

  test "extracts text for every file in the package" do
    ExtractPackageTextJob.perform_now(@package)

    assert_equal "First legal text.", @first_doc_file.reload.extracted_text
    assert_equal "complete", @first_doc_file.extraction_status
    assert_not_nil @first_doc_file.extracted_at

    assert_equal "Second legal text.", @second_doc_file.reload.extracted_text
    assert_equal "complete", @second_doc_file.extraction_status
    assert_not_nil @second_doc_file.extracted_at
  end

  test "continues extracting remaining files when one file fails" do
    failed_doc_file = @package.doc_files.create!(
      file: {
        io: StringIO.new("fake docx"),
        filename: "broken.docx",
        content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      }
    )

    ExtractPackageTextJob.perform_now(@package)

    assert_equal "failed", failed_doc_file.reload.extraction_status
    assert_equal "Zip end of central directory signature not found", failed_doc_file.extraction_error

    assert_equal "First legal text.", @first_doc_file.reload.extracted_text
    assert_equal "complete", @first_doc_file.extraction_status

    assert_equal "Second legal text.", @second_doc_file.reload.extracted_text
    assert_equal "complete", @second_doc_file.extraction_status
  end
end
