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

  private

  def create_doc_file(extraction_status:)
    @package.doc_files.create!(
      extraction_status: extraction_status,
      file: {
        io: StringIO.new("Sample legal text."),
        filename: "#{extraction_status}.txt",
        content_type: "text/plain"
      }
    )
  end
end
