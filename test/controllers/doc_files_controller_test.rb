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
    first_clause = doc_file.clauses.create!(
      package: @package,
      title: "Penalty",
      content: "Late payment attracts a severe penalty.",
      risk_level: "high",
      summary: "Creates a severe late-payment penalty."
    )
    second_clause = doc_file.clauses.create!(
      package: @package,
      title: "Indemnity",
      content: "The tenant indemnifies the landlord.",
      risk_level: "high",
      summary: "Creates a broad indemnity."
    )
    first_clause.flags.create!(name: "Review penalty", level: "high")
    second_clause.flags.create!(name: "Review indemnity", level: "medium")

    get doc_file_url(doc_file)

    assert_response :success
    assert_select "li#doc_file_#{doc_file.id}"
    assert_includes response.body, "sample.txt"
    assert_includes response.body, "Payment obligations."
    assert_includes response.body, "2 flags"
    assert_select "a[href='#{flags_doc_file_path(doc_file)}']", text: "2 flags"
    assert_select "span.pill.badge-success", text: "Complete"
    assert_not_includes response.body, "High-risk clauses"
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

  # CODEX file summary updates
  test "should get summary for current user doc file" do
    doc_file = @package.doc_files.create!(
      extraction_status: "complete",
      extracted_text: "Payment is due within 14 days.",
      ai_status: "complete",
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_doc_file_url(doc_file)

    assert_response :success
    assert_select "h1", text: "sample.txt"
    assert_not_includes response.body, "AI Summary for"
    assert_select "nav[aria-label='Breadcrumb']" do
      assert_select "a[href='#{package_path(@package)}']", text: "Lease review"
      assert_select "[aria-current='page']", count: 0
    end
    assert_select ".item-header-title .subheader", count: 0
    assert_select "form.item-search input[type='hidden'][name='package_id'][value='#{@package.id}']"
    assert_includes response.body, "This file sets payment obligations."
  end

  test "summary should anchor saved clauses" do
    doc_file = @package.doc_files.create!(
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    clause = doc_file.clauses.create!(
      package: @package,
      title: "Payment",
      content: "Payment is due within 14 days.",
      risk_level: "low",
      summary: "Sets a payment deadline.",
      position: 1
    )

    get summary_doc_file_url(doc_file)

    assert_response :success
    assert_select "li##{dom_id(clause)}"
    assert_not_includes response.body, "Risk:"
  end

  test "summary should show solid flag triggers beside flagged clauses" do
    doc_file = @package.doc_files.create!(
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    clause = doc_file.clauses.create!(
      package: @package,
      title: "Payment",
      content: "Payment is due within 14 days.",
      summary: "Sets a payment deadline.",
      position: 1
    )
    clause.flags.create!(
      name: "Confirm payment deadline",
      level: "high",
      category: "legal_review",
      reason: "The deadline requires confirmation."
    )

    get summary_doc_file_url(doc_file)

    assert_response :success
    assert_select "li##{dom_id(clause)}" do
      assert_select "button[aria-label='View flag: Confirm payment deadline']" do
        assert_select "svg[fill='currentColor']"
      end
      assert_select "dialog[data-flag-drawer-target='dialog']" do
        assert_select "h2", text: /Confirm payment deadline/
        assert_select "p", text: "sample.txt"
      end
    end
  end

  test "should highlight requested clause text in summary" do
    doc_file = @package.doc_files.create!(
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    clause = doc_file.clauses.create!(
      package: @package,
      title: "Payment",
      content: "Payment is due within 14 days.",
      risk_level: "low",
      summary: "Sets a payment deadline.",
      position: 1
    )

    get summary_doc_file_url(doc_file), params: { highlight: "payment" }

    assert_response :success
    assert_select "li##{dom_id(clause)} mark[data-summary-highlight-target='match']", text: /payment/i
  end

  test "should only highlight selected clause when opened from package search" do
    doc_file = @package.doc_files.create!(
      ai_summary: "This payment summary should stay plain.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    selected_clause = doc_file.clauses.create!(
      package: @package,
      title: "Payment",
      content: "Payment is due within 14 days.",
      summary: "Sets a payment deadline.",
      position: 1
    )
    other_clause = doc_file.clauses.create!(
      package: @package,
      title: "Other payment",
      content: "Another payment reference.",
      summary: "Also mentions payment.",
      position: 2
    )

    get summary_doc_file_url(
      doc_file,
      highlight: "payment",
      highlight_clause_id: selected_clause.id,
      anchor: dom_id(selected_clause)
    )

    assert_response :success
    assert_select "div#file-summary mark[data-summary-highlight-target='match']", count: 0
    assert_select "li##{dom_id(selected_clause)}.border-cyan-300"
    assert_select "li##{dom_id(selected_clause)} mark[data-summary-highlight-target='match']", text: /payment/i
    assert_select "li##{dom_id(other_clause)} mark[data-summary-highlight-target='match']", count: 0
  end

  test "should highlight requested summary text" do
    doc_file = @package.doc_files.create!(
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_doc_file_url(doc_file), params: { highlight: "payment" }

    assert_response :success
    assert_select "div#file-summary"
    assert_select "mark[data-summary-highlight-target='match']", text: /payment/i
    assert_select "button[data-action='summary-highlight#previous']", count: 0
    assert_select "button[data-action='summary-highlight#next']", count: 0
  end

  test "should not get summary for another user's doc file" do
    other_user = User.create!(email: "summary-other@example.com", password: "password", username: "summaryother")
    other_package = other_user.packages.create!(name: "Private package")
    other_doc_file = other_package.doc_files.create!(
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_doc_file_url(other_doc_file)

    assert_response :not_found
  end

  test "should show all flags for current user doc file" do
    doc_file = @package.doc_files.create!(
      ai_status: "complete",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    low_risk_clause = doc_file.clauses.create!(
      package: @package,
      title: "Payment",
      risk_level: "low",
      position: 1
    )
    low_risk_clause.flags.create!(
      name: "Clarify payment deadline",
      level: "high",
      category: "deadline",
      reason: "The deadline may be too short.",
      suggested_action: "Ask whether the deadline can be extended."
    )
    high_risk_clause = doc_file.clauses.create!(
      package: @package,
      title: "Indemnity",
      risk_level: "high",
      position: 2
    )
    high_risk_clause.flags.create!(name: "Review indemnity", level: "medium")

    get flags_doc_file_url(doc_file)

    assert_response :success
    assert_select "h1", text: /Flags in sample\.txt file/
    assert_select "h1 svg"
    assert_select ".item-header-inner-no-search"
    assert_select "h1 span.break-words", text: /Flags in sample\.txt file/
    assert_select ".item-header-title .subheader", count: 0
    assert_select "form.item-search", count: 0
    assert_select "nav[aria-label='Breadcrumb']" do
      assert_select "a[href='#{package_path(@package)}']", text: "Lease review"
      assert_select "a[href='#{summary_doc_file_path(doc_file)}']", text: "sample.txt"
      assert_select "[aria-current='page']", count: 0
    end
    assert_select "h2", text: "2 Flags"
    assert_includes response.body, "Clarify payment deadline"
    assert_includes response.body, "Review indemnity"
    assert_select "button.btn", text: "See more", count: 2
    assert_select "dialog[data-flag-drawer-target='dialog']", count: 2
    assert_select "article" do
      assert_select "h3", text: "Clarify payment deadline"
      assert_select "h3 + span.pill.badge-danger", text: "High priority"
      assert_select "p", text: /Deadline/
      assert_select "p", text: /Open/
      assert_select "p", text: /deadline may be too short/i, count: 0
    end
    assert_select "article", text: /Review indemnity/ do
      assert_select "span.pill.badge-warning", text: "Medium priority"
    end
    assert_select "dialog", text: /Clarify payment deadline/ do
      assert_select "h2", text: /Clarify payment deadline/
      assert_select "h2 span.pill.badge-danger", text: "High priority"
      assert_select "p", text: "sample.txt"
      assert_select "h3", text: "Reason"
      assert_select "p", text: "The deadline may be too short."
      assert_select "h3", text: "Suggested action"
      assert_select "p", text: "Ask whether the deadline can be extended."
    end
  end

  test "should not show flags for another user's doc file" do
    other_user = User.create!(email: "flags-other@example.com", password: "password", username: "flagsother")
    other_package = other_user.packages.create!(name: "Private package")
    other_doc_file = other_package.doc_files.create!(
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get flags_doc_file_url(other_doc_file)

    assert_response :not_found
  end

  test "should search current user ai summaries" do
    doc_file = @package.doc_files.create!(
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_search_doc_files_url, params: { q: "payment" }

    assert_response :success
    assert_select "turbo-frame#summary_search_results" do
      summary_path = summary_doc_file_path(doc_file, highlight: "payment", anchor: "file-summary")
      assert_select "a[href='#{summary_path}']"
      assert_select "p", text: "sample.txt"
      assert_select "p", text: "Lease review"
      assert_select "mark", text: /payment/i
    end
  end

  test "should search within current package for header search" do
    doc_file = @package.doc_files.create!(
      extracted_text: "The tenant must repair the air conditioner.",
      extraction_status: "complete",
      ai_summary: "This file sets repair obligations. Repair work must be scheduled.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )
    clause = @package.clauses.create!(
      doc_file: doc_file,
      title: "Repairs",
      content: "The tenant must repair the air conditioner.",
      risk_level: "medium",
      summary: "Creates an air conditioner repair obligation.",
      position: 2
    )
    clause.flags.create!(
      name: "Confirm repair responsibility",
      level: "high",
      category: "legal_review",
      reason: "The repair obligation may require legal review."
    )
    other_package = @user.packages.create!(name: "Other repair package")
    other_package.doc_files.create!(
      extracted_text: "Repair obligations in another package.",
      extraction_status: "complete",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_search_doc_files_url, params: { q: "repair", package_id: @package.id }

    assert_response :success
    assert_select "turbo-frame#summary_search_results" do
      assert_select "p", text: /matches in this package/
      assert_select "p", text: "Clause 2 match"
      assert_select "p", text: "Creates an air conditioner repair obligation."
      assert_select "span", text: "medium", count: 0
      assert_select "button[aria-label='View flag: Confirm repair responsibility']" do
        assert_select "svg[fill='currentColor']"
      end
      assert_select "dialog[data-flag-drawer-target='dialog']" do
        assert_select "h2", text: /Confirm repair responsibility/
        assert_select "p", text: "sample.txt"
      end
      clause_path = summary_doc_file_path(doc_file, highlight: "repair", anchor: dom_id(clause))
      focused_clause_path = summary_doc_file_path(
        doc_file,
        highlight: "repair",
        highlight_clause_id: clause.id,
        anchor: dom_id(clause)
      )
      assert_select "a[href='#{focused_clause_path}']", text: "Open clause"
      assert_select "a[href='#{clause_path}']", text: "Open clause", count: 0
      summary_path = summary_doc_file_path(doc_file, highlight: "repair", anchor: "file-summary")
      assert_select "a[href='#{summary_path}']" do
        assert_select "p", text: /AI summary match/
        assert_select "span", text: /matches/, count: 0
      end
      assert_select "p", text: "Other repair package", count: 0
      assert_select "mark", text: /repair/i
    end
    assert response.body.index("Clause 2 match") < response.body.index("AI summary match")
  end

  test "should only search ai summary and clauses within current package header search" do
    @package.update!(
      name: "Payment workspace",
      category: "Payment category",
      overview: "Payment overview",
      status: "Payment status"
    )
    @package.doc_files.create!(
      ai_micro_summary: "Payment micro summary.",
      ai_error: "Payment AI error.",
      extraction_error: "Payment extraction error.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_search_doc_files_url, params: { q: "payment", package_id: @package.id }

    assert_response :success
    assert_select "turbo-frame#summary_search_results" do
      assert_select "p", text: "No matching package results"
      assert_select "button[data-action='search-drawer#close ai-chat-drawer#ask']", text: "Ask AI for help"
      assert_select "button[data-ai-chat-drawer-question-param='Can you help me find anything related to \"payment\" in this package?']"
      assert_select "p", text: /Package name match/, count: 0
      assert_select "p", text: /File name match/, count: 0
      assert_select "p", text: /Package category match/, count: 0
      assert_select "p", text: /AI micro summary match/, count: 0
      assert_select "p", text: /AI error match/, count: 0
      assert_select "p", text: /Extraction error match/, count: 0
    end
  end

  test "should not search extracted text within current package header search" do
    @package.doc_files.create!(
      extracted_text: "The tenant must repair the air conditioner.",
      extraction_status: "complete",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_search_doc_files_url, params: { q: "conditioner", package_id: @package.id }

    assert_response :success
    assert_select "turbo-frame#summary_search_results" do
      assert_select "p", text: "No matching package results"
      assert_select "p", text: "Extracted text match", count: 0
    end
  end

  test "should not search another user's ai summaries" do
    other_user = User.create!(
      email: "summary-search-other@example.com",
      password: "password",
      username: "summarysearchother"
    )
    other_package = other_user.packages.create!(name: "Private package")
    other_package.doc_files.create!(
      ai_summary: "This file sets payment obligations.",
      file: fixture_file_upload("sample.txt", "text/plain")
    )

    get summary_search_doc_files_url, params: { q: "payment" }

    assert_response :success
    assert_select "turbo-frame#summary_search_results" do
      assert_select "p", text: "No matching summaries"
      assert_select "p", text: "Private package", count: 0
    end
  end
end
