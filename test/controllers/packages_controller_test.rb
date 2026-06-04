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
      assert_select "p", text: "Lease review", count: 0
    end
  end

  # CODEX search function updates
  test "should only search current user packages" do
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

  test "should get show" do
    get package_url(@package)
    assert_response :success
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
end
