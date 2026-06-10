require "test_helper"

class FlagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "flags-controller@example.com", password: "password", username: "flagscontroller")
    package = @user.packages.create!(name: "Lease review")
    clause = package.clauses.create!(
      title: "Payment",
      content: "Payment is due within 14 days.",
      risk_level: "high",
      summary: "Creates a short payment deadline.",
      position: 1
    )
    @flag = clause.flags.create!(
      name: "Clarify payment deadline",
      level: "high",
      category: "deadline",
      suggested_action: "Ask whether the deadline can be extended."
    )

    sign_in @user
  end

  test "should resolve current user's flag" do
    patch flag_url(@flag), params: { flag: { resolved: true, resolution_note: "Confirmed with the agent." } }

    assert_redirected_to package_path(@flag.clause.package)
    assert @flag.reload.resolved?
    assert_equal "Confirmed with the agent.", @flag.resolution_note
    assert_not_nil @flag.resolved_at
  end

  test "should add a default resolution note when resolving without one" do
    patch flag_url(@flag), params: { flag: { resolved: true, resolution_note: "" } }

    assert_redirected_to package_path(@flag.clause.package)
    assert @flag.reload.resolved?
    assert_equal "No notes added", @flag.resolution_note
  end

  test "should resolve current user's flag with turbo stream replacement" do
    patch flag_url(@flag),
          params: { flag: { resolved: true, resolution_note: "Added to negotiation list." } },
          as: :turbo_stream

    assert_response :success
    assert @flag.reload.resolved?
    assert_select "turbo-stream[action='replace'][target='flag_#{@flag.id}']"
    assert_includes response.body, "Reopen"
    assert_includes response.body, "Resolved"
    assert_includes response.body, "Deadline"
    assert_includes response.body, "Suggested action"
    assert_includes response.body, "Added to negotiation list."
  end

  test "should preserve icon trigger when resolving from a search result" do
    patch flag_url(@flag),
          params: {
            flag: { resolved: true, resolution_note: "" },
            render_context: "icon_trigger"
          },
          as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='flag_#{@flag.id}']"
    assert_select "button[aria-label='View flag: Clarify payment deadline']"
    assert_includes response.body, "No notes added"
  end

  test "should not update another user's flag" do
    other_user = User.create!(email: "other-flag@example.com", password: "password", username: "otherflag")
    other_package = other_user.packages.create!(name: "Other package")
    other_clause = other_package.clauses.create!(title: "Private clause", risk_level: "high")
    other_flag = other_clause.flags.create!(name: "Private flag", level: "high")

    patch flag_url(other_flag), params: { flag: { resolved: true } }

    assert_response :not_found
    assert_not other_flag.reload.resolved?
  end
end
