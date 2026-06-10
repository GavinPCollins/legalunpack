require "test_helper"

class LegalSourcesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "admin can view source management" do
    admin = User.create!(email: "admin@example.com", password: "password", username: "admin", admin: true)
    LegalSource.create!(
      title: "Residential Tenancies Act 1997",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      publisher: "Victorian Legislation",
      source_url: "https://example.com/residential-tenancies",
      source_format: "html"
    )
    sign_in admin

    get legal_sources_url

    assert_response :success
    assert_select "h1", text: "Source Management"
    assert_select "a", text: "Add resource"
    assert_select "h2", text: "Residential Tenancies Act 1997"
  end

  test "admin can create legal source with uploaded file" do
    admin = User.create!(email: "source-admin@example.com", password: "password", username: "sourceadmin", admin: true)
    sign_in admin

    assert_difference("LegalSource.count", 1) do
      post legal_sources_url, params: {
        legal_source: {
          title: "Uploaded guidance",
          jurisdiction: "VIC",
          source_type: "regulator_guidance",
          authority_level: "guidance",
          publisher: "Consumer Affairs Victoria",
          source_format: "txt",
          source_file: fixture_file_upload("sample.txt", "text/plain")
        }
      }
    end

    legal_source = LegalSource.order(:created_at).last
    assert_redirected_to legal_sources_path
    assert legal_source.source_file.attached?
  end

  test "non-admin cannot access source management" do
    user = User.create!(email: "normal@example.com", password: "password", username: "normal")
    sign_in user

    get legal_sources_url

    assert_redirected_to root_path
  end

  test "sidebar link is only visible to admins" do
    user = User.create!(email: "sidebar-user@example.com", password: "password", username: "sidebaruser")
    sign_in user

    get new_package_url
    assert_response :success
    assert_select "a", text: "Source management", count: 0

    sign_out user

    admin = User.create!(email: "sidebar-admin@example.com", password: "password", username: "sidebaradmin", admin: true)
    sign_in admin

    get new_package_url
    assert_response :success
    assert_select "a", text: "Source management"
  end
end
