require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "returns the YAML default when no override exists" do
    assert_equal 10, Setting.get("prefilter.min_employees")
    assert_equal "claude-haiku-5-5", Setting.get("models.scoring")
  end

  test "database override wins over the default" do
    Setting.set("prefilter.min_employees", 25)
    assert_equal 25, Setting.get("prefilter.min_employees")
  end

  test "reset restores the default" do
    Setting.set("prefilter.max_employees", 50)
    Setting.reset("prefilter.max_employees")
    assert_equal 200, Setting.get("prefilter.max_employees")
  end

  test "supports array and null values" do
    assert_equal %w[5613 561422], Setting.get("prefilter.excluded_naics_prefixes")
    Setting.reset("budget.spending_cap_usd") # tests run under a cap; the shipped default must be unset
    assert_nil Setting.get("budget.spending_cap_usd")
  end

  test "unknown key returns nil" do
    assert_nil Setting.get("nope.nothing")
  end
end
