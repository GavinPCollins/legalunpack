require "test_helper"

class ClauseTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "clause@example.com", password: "password", username: "clause")
    @package = user.packages.create!(name: "Lease review")
    @doc_file = @package.doc_files.create!(
      file: {
        io: StringIO.new("Sample legal text."),
        filename: "sample.txt",
        content_type: "text/plain"
      }
    )
  end

  test "can store ai clause fields for a doc file" do
    clause = @package.clauses.create!(
      doc_file: @doc_file,
      title: "Payment",
      content: "Payment is due within 14 days.",
      risk_level: "low",
      summary: "Sets a short payment deadline.",
      position: 1
    )

    assert_equal @doc_file, clause.doc_file
    assert_equal [ clause ], @doc_file.clauses.to_a
    assert_equal "Payment", clause.title
    assert_equal "low", clause.risk_level
    assert_equal "Sets a short payment deadline.", clause.summary
    assert_equal 1, clause.position
  end

  test "doc file is optional for existing package level clauses" do
    clause = @package.clauses.build(content: "Package-level clause.")

    assert clause.valid?
  end

  test "risk level must be low medium or high when present" do
    clause = @package.clauses.build(content: "Risky clause.", risk_level: "severe")

    assert_not clause.valid?
    assert_includes clause.errors[:risk_level], "is not included in the list"
  end
end
