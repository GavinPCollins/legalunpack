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
    assert_select "a", text: "Remove resource"
    assert_select "h2", text: "Residential Tenancies Act 1997"
  end

  test "admin can view remove controls" do
    admin = User.create!(email: "remove-mode-admin@example.com", password: "password", username: "removemodeadmin", admin: true)
    LegalSource.create!(
      title: "Source to remove",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      source_url: "https://example.com/source-to-remove",
      source_format: "html"
    )
    sign_in admin

    get legal_sources_url(remove: true)

    assert_response :success
    assert_select "a", text: "Done removing"
    assert_select "form[action='#{legal_source_path(LegalSource.find_by!(title: "Source to remove"))}'] button", text: "Remove resource"
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
    assert_equal "Legal source added and imported.", flash[:notice]
    assert_equal "Sample legal text.", legal_source.raw_text
    assert legal_source.imported?
    assert_equal 1, legal_source.legal_source_chunks.count
    assert_equal "Sample legal text.", legal_source.legal_source_chunks.first.content
  end

  test "admin can autofill metadata from uploaded file" do
    admin = User.create!(email: "autofill-admin@example.com", password: "password", username: "autofilladmin", admin: true)
    original_call = LegalSourceMetadataExtractor.method(:call)
    LegalSourceMetadataExtractor.define_singleton_method(:call) do |_uploaded_file|
      {
        "title" => "Residential Tenancies Act 1997",
        "citation" => "Authorised Version No. 111",
        "jurisdiction" => "VIC",
        "source_type" => "act",
        "authority_level" => "legislation",
        "publisher" => "Victorian Legislation",
        "source_format" => "txt"
      }
    end
    sign_in admin

    post autofill_legal_sources_url,
         params: { source_file: fixture_file_upload("sample.txt", "text/plain") },
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Residential Tenancies Act 1997", json.dig("metadata", "title")
    assert_equal "Victorian Legislation", json.dig("metadata", "publisher")
  ensure
    LegalSourceMetadataExtractor.define_singleton_method(:call, original_call) if original_call
  end

  test "non-admin cannot autofill metadata" do
    user = User.create!(email: "autofill-user@example.com", password: "password", username: "autofilluser")
    sign_in user

    post autofill_legal_sources_url,
         params: { source_file: fixture_file_upload("sample.txt", "text/plain") },
         as: :json

    assert_redirected_to root_path
  end

  test "non-admin cannot access source management" do
    user = User.create!(email: "normal@example.com", password: "password", username: "normal")
    sign_in user

    get legal_sources_url

    assert_redirected_to root_path
  end

  test "admin can remove legal source" do
    admin = User.create!(email: "remove-admin@example.com", password: "password", username: "removeadmin", admin: true)
    legal_source = LegalSource.create!(
      title: "Old source",
      jurisdiction: "VIC",
      source_type: "act",
      authority_level: "legislation",
      source_url: "https://example.com/old-source",
      source_format: "html"
    )
    sign_in admin

    assert_difference("LegalSource.count", -1) do
      delete legal_source_url(legal_source)
    end

    assert_redirected_to legal_sources_path(remove: true)
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
