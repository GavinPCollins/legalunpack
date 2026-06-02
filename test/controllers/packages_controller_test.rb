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

    assert_difference("Package.count", 1) do
      post packages_url, params: { package: { name: "Court notice" }, files: [uploaded_file] }
    end

    assert_redirected_to package_url(Package.order(:created_at).last)
  end

  test "should reject create without a file" do
    assert_no_difference("Package.count") do
      post packages_url, params: { package: { name: "Court notice" } }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Must contain at least 1 file"
  end

  test "should reject create without a package name" do
    uploaded_file = fixture_file_upload("sample.txt", "text/plain")

    assert_no_difference("Package.count") do
      post packages_url, params: { package: { name: "" }, files: [uploaded_file] }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Must name package"
  end

  test "should create package with uploaded files and pasted text" do
    uploaded_file = fixture_file_upload("sample.txt", "text/plain")

    assert_difference("Package.count", 1) do
      assert_difference("DocFile.count", 2) do
        post packages_url, params: {
          package: { name: "Employment contract" },
          files: [uploaded_file],
          pasted_text: "A pasted legal clause."
        }
      end
    end

    package = Package.order(:created_at).last

    assert_redirected_to package_url(package)
    assert_equal 2, package.doc_files.count
    assert package.doc_files.all? { |doc_file| doc_file.file.attached? }
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
