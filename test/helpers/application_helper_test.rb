require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  FlagSummary = Struct.new(:name, :reason, :level, :resolved) do
    def resolved? = resolved
  end
  ClauseSummary = Struct.new(:title, :summary)

  test "combines two distinct flag names in a clause group title" do
    clause = ClauseSummary.new("Repairs", nil)
    flags = [
      FlagSummary.new("Unclear repair timeline", nil, "high", false),
      FlagSummary.new("Restricted repair reporting", nil, "medium", false)
    ]

    assert_equal "Unclear repair timeline and Restricted repair reporting", flag_group_title(clause, flags)
  end

  test "uses a multiple concerns title for three or more flags" do
    clause = ClauseSummary.new("Repairs", nil)
    flags = [
      FlagSummary.new("Unclear repair timeline", nil, "high", false),
      FlagSummary.new("Restricted repair reporting", nil, "medium", false),
      FlagSummary.new("Uncapped repair costs", nil, "high", false)
    ]

    assert_equal "Multiple concerns in Repairs", flag_group_title(clause, flags)
  end

  test "uses the highest unresolved priority for a group" do
    flags = [
      FlagSummary.new("Resolved serious concern", nil, "high", true),
      FlagSummary.new("Open concern", nil, "medium", false)
    ]

    assert_equal "Open concern", highest_priority_flag(flags).name
  end
end
