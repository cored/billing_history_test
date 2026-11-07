require "bigdecimal"

# Variant A: event log is the source of truth; money is folded from typed facts.
module EventLog
  UsageReported          = Struct.new(:id, :period, :metric, :units)
  LateBillableUsageAdded = Struct.new(:id, :period, :metric, :units)
  InvoiceIssued          = Struct.new(:period, :kind, :total_cents)

  class Billing
    def initialize(price_cents) = (@price = price_cents; @events = [])

    def report(id:, period:, metric:, units:, late: false)
      return if @events.any? { |e| e.respond_to?(:id) && e.id == id }   # exactly once
      @events << (late ? LateBillableUsageAdded : UsageReported).new(id, period, metric, units)
    end

    def issue(period)
      owed = folded_total(period) - invoiced(period)
      @events << InvoiceIssued.new(period, invoiced(period).zero? ? :invoice : :adjustment, owed)
      owed
    end

    private

    def folded_total(period)
      usage = @events.select { |e| e.respond_to?(:units) && e.period == period }
      usage.group_by(&:metric).sum do |_metric, rows|
        (rows.sum(&:units) * @price).round(0, BigDecimal::ROUND_HALF_UP).to_i  # per-line rounding
      end
    end

    def invoiced(period) = @events.grep(InvoiceIssued).select { _1.period == period }.sum(&:total_cents)
  end
end

# Variant B: append-only usage table (unique id) + append-only ledger of invoice/adjustment rows.
module Ledger
  UsageRow  = Struct.new(:id, :period, :metric, :units, :late)
  LedgerRow = Struct.new(:period, :kind, :total_cents)

  class Billing
    def initialize(price_cents) = (@price = price_cents; @usage = {}; @ledger = [])

    def report(id:, period:, metric:, units:, late: false)
      @usage[id] ||= UsageRow.new(id, period, metric, units, late)   # unique index
    end

    def issue(period)
      owed = computed_total(period) - billed(period)
      @ledger << LedgerRow.new(period, billed(period).zero? ? :invoice : :adjustment, owed)
      owed
    end

    private

    def computed_total(period)
      @usage.values.select { _1.period == period }.group_by(&:metric).sum do |_metric, rs|
        (rs.sum(&:units) * @price).round(0, BigDecimal::ROUND_HALF_UP).to_i
      end
    end

    def billed(period) = @ledger.select { _1.period == period }.sum(&:total_cents)
  end
end
