# CODEX add document
require "test_helper"

class DocFilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "doc-files@example.com", password: "password", username: "docfiles")
    @package = @user.packages.create!(name: "Lease review")

    sign_in @user
  end

  test "should add uploaded document to current user package" do
    uploaded_file = fixture_file_upload("sample.txt", "text/plain")

    assert_enqueued_with(job: ExtractPackageTextJob, args: [ @package ]) do
      assert_difference("DocFile.count", 1) do
        post doc_files_url, params: { package_id: @package.id, files: [uploaded_file] }
      end
    end

    assert_redirected_to package_url(@package)
    assert_equal "sample.txt", @package.doc_files.last.file.filename.to_s
  end

  test "should show rendered document row for polling" do
    doc_file = @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Payment is due within 14 days.",
      ai_status: "complete",
      ai_summary: "This file sets payment obligations.",
      ai_micro_summary: "Payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    doc_file.clauses.create!(
      package: @package,
      title: "Penalty",
      content: "Late payment attracts a severe penalty.",
      risk_level: "high",
      summary: "Creates a severe late-payment penalty."
    )
    doc_file.clauses.create!(
      package: @package,
      title: "Indemnity",
      content: "The tenant indemnifies the landlord.",
      risk_level: "high",
      summary: "Creates a broad indemnity."
    )

    get doc_file_url(doc_file)

    assert_response :success
    assert_select "li#doc_file_#{doc_file.id}"
    assert_includes response.body, "sample.txt"
    assert_includes response.body, "Payment obligations."
    assert_includes response.body, "2 high-risk clauses"
    assert_includes response.body, "Complete"
  end

  test "should not show another user's document row" do
    other_user = User.create!(email: "other-doc-file-show@example.com", password: "password", username: "otherdocfileshow")
    other_package = other_user.packages.create!(name: "Private package")
    other_doc_file = other_package.doc_files.create!(
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get doc_file_url(other_doc_file)

    assert_response :not_found
  end

  test "should reject add document without a file" do
    assert_no_difference("DocFile.count") do
      post doc_files_url, params: { package_id: @package.id }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Choose at least 1 file"
  end

  test "should not add document to another user's package" do
    other_user = User.create!(email: "other-doc-files@example.com", password: "password", username: "otherdocfiles")
    other_package = other_user.packages.create!(name: "Private package")
    uploaded_file = fixture_file_upload("sample.txt", "text/plain")

    assert_no_difference("DocFile.count") do
      post doc_files_url, params: { package_id: other_package.id, files: [uploaded_file] }
    end

    assert_response :not_found
  end
end
