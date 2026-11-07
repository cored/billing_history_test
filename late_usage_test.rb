require "minitest/autorun"
require_relative "late_usage_designs"

# Same spec, both designs. Price is 1.5 cents per unit, as a BigDecimal on purpose:
# a Float price fails here, because Float#round takes no rounding mode.
PRICE = BigDecimal("1.5")

[EventLog::Billing, Ledger::Billing].each do |design|
  Class.new(Minitest::Test) do
    define_method("test_retry_counted_once_#{design}") do
      b = design.new(PRICE)
      2.times { b.report(id: "u1", period: "2026-11", metric: "api_calls", units: 10) }
      assert_equal 15, b.issue("2026-11")
    end

    define_method("test_late_usage_becomes_exact_adjustment_#{design}") do
      b = design.new(PRICE)
      b.report(id: "u1", period: "2026-11", metric: "api_calls", units: 10)
      assert_equal 15, b.issue("2026-11")
      b.report(id: "u2", period: "2026-11", metric: "api_calls", units: 4, late: true)
      assert_equal 6, b.issue("2026-11")
    end

    define_method("test_rounding_is_per_line_#{design}") do
      b = design.new(PRICE)
      b.report(id: "u1", period: "2026-11", metric: "api_calls", units: 1)
      b.report(id: "u2", period: "2026-11", metric: "storage_gb", units: 1)
      assert_equal 4, b.issue("2026-11") # whole-invoice rounding would give 3
    end
  end
end
