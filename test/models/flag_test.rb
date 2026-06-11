require "test_helper"

class FlagTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "flag@example.com", password: "password", username: "flag")
    package = user.packages.create!(name: "Lease review")
    @clause = package.clauses.create!(
      title: "Payment",
      content: "Payment is due within 14 days.",
      risk_level: "high",
      summary: "Creates a short payment deadline.",
      position: 1
    )
  end

  test "belongs to a clause and starts unresolved" do
    flag = @clause.flags.create!(
      name: "Clarify payment deadline",
      reason: "The timeframe may need follow-up.",
      level: "high",
      category: "deadline",
      suggested_action: "Ask whether the deadline can be extended."
    )

    assert_equal @clause, flag.clause
    assert_equal "deadline", flag.category
    assert_equal "Ask whether the deadline can be extended.", flag.suggested_action
    assert_not flag.resolved?
    assert_nil flag.resolved_at
  end

  test "sets resolved timestamp when resolved" do
    flag = @clause.flags.create!(name: "Review clause", level: "medium")

    flag.update!(resolved: true)

    assert flag.resolved?
    assert_not_nil flag.resolved_at
  end

  test "clears resolved timestamp when reopened" do
    flag = @clause.flags.create!(
      name: "Review clause",
      level: "medium",
      resolved: true,
      resolution_note: "Accepted after review.",
      note: "Keep this note."
    )

    flag.update!(resolved: false)

    assert_not flag.resolved?
    assert_nil flag.resolved_at
    assert_nil flag.resolution_note
    assert_equal "Keep this note.", flag.note
  end

  test "can store one user note" do
    flag = @clause.flags.create!(name: "Review clause", note: "Discuss this with the agent.")

    assert_equal "Discuss this with the agent.", flag.note
  end

  test "level must be low medium or high when present" do
    flag = @clause.flags.build(name: "Review clause", level: "urgent")

    assert_not flag.valid?
    assert_includes flag.errors[:level], "is not included in the list"
  end

  test "category must be one of the supported categories when present" do
    flag = @clause.flags.build(name: "Review clause", category: "admin")

    assert_not flag.valid?
    assert_includes flag.errors[:category], "is not included in the list"
  end
end
