require "test_helper"

class PackagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "packages@example.com", password: "password", username: "packages")
    @package = @user.packages.create!(name: "Lease review")

    sign_in @user
  end

  test "should get index" do
    get packages_url
    assert_response :success

    assert_select "turbo-frame#package_search_results" do |frame|
      assert_empty frame.first.text.strip
    end
  end

  # CODEX search function updates
  test "should search by package name" do
    @user.packages.create!(name: "Court notice")

    get packages_url, params: { q: "court" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "Court notice"
      assert_select "mark", text: /Court/i
      assert_select "span", text: "Open package"
      assert_select "p", text: "Lease review", count: 0
    end
  end

  # CODEX search function updates
  test "should search by uploaded filename" do
    package = @user.packages.create!(name: "Employment contract")
    package.doc_files.create!(file: fixture_file_upload("sample.txt", "text/plain"))

    get packages_url, params: { q: "sample" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "Employment contract"
      assert_select "p", text: "sample.txt"
      assert_select "mark", text: /sample/i
      assert_select "span", text: "Open package"
      assert_select "p", text: "Lease review", count: 0
    end
  end

  # CODEX search function updates
  test "should not search uploaded file ai summary" do
    @user.packages.create!(name: "Supplier agreement").doc_files.create!(
      ai_summary: "This document explains indemnity obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get packages_url, params: { q: "indemnity" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "No matching packages"
      assert_select "p", text: "Supplier agreement", count: 0
    end
  end

  # CODEX search function updates
  test "should not search package metadata" do
    @user.packages.create!(
      name: "Matter folder",
      category: "Tenancy",
      overview: "Retail premises disclosure pack",
      status: "reviewing"
    )

    get packages_url, params: { q: "disclosure" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "No matching packages"
      assert_select "p", text: "Matter folder", count: 0
    end
  end

  # CODEX search function updates
  test "should not search extracted file text" do
    @user.packages.create!(name: "Lease evidence").doc_files.create!(
      extracted_text: "The tenant must repair the air conditioner.",
      extraction_status: "complete",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get packages_url, params: { q: "conditioner" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "No matching packages"
      assert_select "p", text: "Lease evidence", count: 0
    end
  end

  # CODEX search function updates
  test "should not search uploaded file ai micro summary" do
    @user.packages.create!(name: "Vendor agreement").doc_files.create!(
      ai_micro_summary: "Assignment consent required.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get packages_url, params: { q: "assignment" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "No matching packages"
      assert_select "p", text: "Vendor agreement", count: 0
    end
  end

  # CODEX search function updates
  test "should not search clause ai analysis" do
    package = @user.packages.create!(name: "Risk review")
    doc_file = package.doc_files.create!(file: fixture_file_upload("sample.txt", "text/plain"))
    package.clauses.create!(
      doc_file: doc_file,
      title: "Make good",
      content: "Tenant must reinstate the premises at expiry.",
      risk_level: "high",
      summary: "Creates a broad reinstatement obligation.",
      position: 1
    )

    get packages_url, params: { q: "reinstatement" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "No matching packages"
      assert_select "p", text: "Risk review", count: 0
    end
  end

  # CODEX search function updates
  test "should keep results ordered by newest first" do
    older_package = @user.packages.create!(name: "Repair older")
    newer_package = @user.packages.create!(name: "Repair newer")
    older_package.update!(created_at: 2.days.ago)
    newer_package.update!(created_at: 1.day.ago)

    get packages_url, params: { q: "repair" }

    assert_response :success
    assert response.body.index("Repair newer") < response.body.index("Repair older")
  end

  # CODEX search function updates
  test "should not search another user's packages by name or filename" do
    other_user = User.create!(email: "other@example.com", password: "password", username: "other")
    other_package = other_user.packages.create!(name: "Private settlement")
    other_package.doc_files.create!(file: fixture_file_upload("sample.txt", "text/plain"))

    get packages_url, params: { q: "private" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "Private settlement", count: 0
      assert_select "p", text: "No matching packages"
    end
  end

  # CODEX search function updates
  test "should not search another user's uploaded filename" do
    other_user = User.create!(email: "other-filename@example.com", password: "password", username: "otherfilename")
    other_package = other_user.packages.create!(name: "Other package")
    other_package.doc_files.create!(file: fixture_file_upload("sample.txt", "text/plain"))

    get packages_url, params: { q: "sample" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "Other package", count: 0
      assert_select "p", text: "No matching packages"
    end
  end

  # CODEX search function updates
  test "should show no matches for another user's package names" do
    other_user = User.create!(email: "private@example.com", password: "password", username: "private")
    other_user.packages.create!(name: "Private settlement")

    get packages_url, params: { q: "private" }

    assert_response :success
    assert_select "turbo-frame#package_search_results" do
      assert_select "p", text: "No matching packages"
      assert_select "p", text: "Private settlement", count: 0
    end
  end

  test "should get show" do
    get package_url(@package)

    assert_response :success
    assert_select "form[action='#{package_path(@package)}'][method='post'] button", text: "Delete package" do |buttons|
      assert buttons.size >= 2, "expected at least 2 Delete package buttons, found #{buttons.size}"
    end
  end

  test "file flag icon links to the file flags page" do
    doc_file = @package.doc_files.create!(
      ai_status: "complete",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    clause = doc_file.clauses.create!(
      package: @package,
      title: "Payment",
      risk_level: "low"
    )
    clause.flags.create!(name: "Clarify payment deadline", level: "high")

    get package_url(@package)

    assert_response :success
    assert_select "a[href='#{flags_doc_file_path(doc_file)}']" do
      assert_select "svg"
      assert_select "span", text: "1"
    end
    assert_select "a[href='#{flags_doc_file_path(doc_file)}']", text: "Review flags"
    assert_includes response.body, "1 flag found."
    assert_not_includes response.body, "high-risk"
    assert_select "dialog[id='#{dom_id(doc_file, :package_risks)}']", count: 0
  end

  test "should enqueue text extraction when opening package with unextracted files" do
    @package.doc_files.create!(
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    assert_enqueued_with(job: ExtractPackageTextJob, args: [ @package ]) do
      get package_url(@package)
    end

    assert_response :success
  end

  test "should not enqueue text extraction when opening package with extracted files only" do
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Already extracted.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    assert_no_enqueued_jobs(only: ExtractPackageTextJob) do
      get package_url(@package)
    end

    assert_response :success
  end

  test "should show analysis task for uploaded files needing ai" do
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Ready to analyze.",
      ai_status: "pending",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    @package.doc_files.create!(
      extraction_status: "pending",
      ai_status: "pending",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get package_url(@package)

    assert_response :success
    assert_includes response.body, "Analysis required"
    assert_match(/2 uploaded files\s+require AI analysis\./, response.body)
    assert_select "form[action='#{analyze_package_path(@package)}'][method='post'] button", text: "Run analysis"
    assert_select "form[data-action='submit->package-status-poll#markAnalysisStarted']"
    assert_select "p", text: "Nothing needs attention", count: 0
  end

  test "should not show analysis task for failed files" do
    error_message = "Request body too large for gpt-4.1-mini model. Max size: 8000 tokens."
    @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Could not analyze.",
      ai_status: "failed",
      ai_error: %(GitHub Models request failed: 413 {"message":"#{error_message}"}),
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get package_url(@package)

    assert_response :success
    assert_includes response.body, "Failed to analyse - sample.txt"
    assert_includes response.body, "Reason:"
    assert_includes response.body, error_message
    assert_includes response.body, "Upload different file or call customer support"
    assert_select "form[action='#{doc_file_path(@package.doc_files.first)}'][method='post'] button", text: "Delete file"
    assert_select "h3", text: "Analysis required", count: 0
  end

  test "should get analysis" do
    doc_file = @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Payment is due within 14 days.",
      ai_status: "complete",
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    @package.clauses.create!(
      doc_file: doc_file,
      title: "Payment",
      content: "Payment is due within 14 days.",
      risk_level: "low",
      summary: "Sets a payment deadline.",
      position: 1
    )

    get analysis_package_url(@package)

    assert_response :success
    assert_includes response.body, "This file sets payment obligations."
    assert_includes response.body, "Payment"
    assert_includes response.body, "Sets a payment deadline."
    assert_not_includes response.body, "Risk:"
  end

  test "should mark unfinished files as processing when analysis starts" do
    pending_doc_file = @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Ready to analyze.",
      ai_status: "pending",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    complete_doc_file = @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Already analyzed.",
      ai_status: "complete",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    assert_enqueued_with(job: AnalyzePackageFilesJob, args: [ @package ]) do
      post analyze_package_url(@package)
    end

    assert_redirected_to package_url(@package)
    assert_equal "processing", pending_doc_file.reload.ai_status
    assert_equal "complete", complete_doc_file.reload.ai_status

    get package_url(@package)

    assert_response :success
    assert_includes response.body, "Analyzing file..."
    assert_select "[data-package-status-poll-target='analysisAction']", text: "Analyzing file..."
    assert_select "[data-package-status-poll-target='analysisAction'] form[action='#{analyze_package_path(@package)}']", count: 0
    assert_select "[data-controller~='package-status-poll'][data-package-status-poll-active-value='true']"
  end

  test "should not get analysis for another user's package" do
    other_user = User.create!(email: "analysis-page-other@example.com", password: "password", username: "analysispageother")
    other_package = other_user.packages.create!(name: "Private analysis")

    get analysis_package_url(other_package)

    assert_response :not_found
  end

  test "should get new" do
    get new_package_url
    assert_response :success
  end

  test "should post create" do
    uploaded_file = fixture_file_upload("sample.txt", "text/plain")

    assert_enqueued_with(job: ExtractPackageTextJob) do
      assert_difference("Package.count", 1) do
        post packages_url, params: { package: { name: "Court notice" }, files: [uploaded_file] }
      end
    end

    assert_redirected_to package_url(Package.order(:created_at).last)
  end

  test "should reject create without a file" do
    assert_no_enqueued_jobs(only: ExtractPackageTextJob) do
      assert_no_difference("Package.count") do
        post packages_url, params: { package: { name: "Court notice" } }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Must contain at least 1 file"
  end

  test "should reject create without a package name" do
    uploaded_file = fixture_file_upload("sample.txt", "text/plain")

    assert_no_enqueued_jobs(only: ExtractPackageTextJob) do
      assert_no_difference("Package.count") do
        post packages_url, params: { package: { name: "" }, files: [uploaded_file] }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Must name package"
  end

  test "should create package with uploaded files and pasted text" do
    uploaded_file = fixture_file_upload("sample.txt", "text/plain")

    assert_enqueued_with(job: ExtractPackageTextJob) do
      assert_difference("Package.count", 1) do
        assert_difference("DocFile.count", 2) do
          post packages_url, params: {
            package: { name: "Employment contract" },
            files: [uploaded_file],
            pasted_text: "A pasted legal clause."
          }
        end
      end
    end

    package = Package.order(:created_at).last

    assert_redirected_to package_url(package)
    assert_equal 2, package.doc_files.count
    assert package.doc_files.all? { |doc_file| doc_file.file.attached? }
  end

  test "should create package with pasted text only" do
    assert_enqueued_with(job: ExtractPackageTextJob) do
      assert_difference("Package.count", 1) do
        assert_difference("DocFile.count", 1) do
          post packages_url, params: {
            package: { name: "Pasted notice" },
            pasted_text: "A pasted legal notice."
          }
        end
      end
    end

    package = Package.order(:created_at).last
    doc_file = package.doc_files.first

    assert_redirected_to package_url(package)
    assert_equal "pasted-text.txt", doc_file.file.filename.to_s
    assert_equal "text/plain", doc_file.file.content_type
    assert_equal "A pasted legal notice.", doc_file.file.download
  end

  test "should reject create with unsupported uploaded file type" do
    uploaded_file = fixture_file_upload("sample.txt", "text/html")

    assert_no_enqueued_jobs(only: ExtractPackageTextJob) do
      assert_no_difference([ "Package.count", "DocFile.count" ]) do
        post packages_url, params: { package: { name: "Bad upload" }, files: [ uploaded_file ] }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "File must be a PDF, DOCX, TXT, or RTF file"
  end

  test "should get edit" do
    get edit_package_url(@package)
    assert_response :success
  end

  test "should patch update" do
    patch package_url(@package), params: { package: { name: "Updated lease review" } }

    assert_redirected_to package_url(@package)
    assert_equal "Updated lease review", @package.reload.name
  end

  test "should delete destroy" do
    assert_difference("Package.count", -1) do
      delete package_url(@package)
    end

    assert_redirected_to packages_url
  end

  test "should enqueue package ai analysis" do
    assert_enqueued_with(job: AnalyzePackageFilesJob, args: [ @package ]) do
      post analyze_package_url(@package)
    end

    assert_redirected_to package_url(@package)
    assert_equal "AI analysis started.", flash[:notice]
  end

  test "should not enqueue ai analysis for another user's package" do
    other_user = User.create!(email: "analysis-other@example.com", password: "password", username: "analysisother")
    other_package = other_user.packages.create!(name: "Private analysis")

    assert_no_enqueued_jobs(only: AnalyzePackageFilesJob) do
      post analyze_package_url(other_package)
    end

    assert_response :not_found
  end
end
