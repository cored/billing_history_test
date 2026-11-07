# billing-history-counter-tests

Does billing need an event store? This repo tests that question with code you can run.

Each test writes the same billing logic twice, once with an event log as the source of truth and once with plain append-only tables, then runs one spec against both designs.

## Test 1: late usage [Snippets of Code](https://snippetsofcode.substack.com/)

The spec checks three things:

1. A retried usage report is counted once.
2. Usage that arrives after an invoice becomes an exact adjustment.
3. Rounding is per line, half-up, to the cent.

```
ruby late_usage_test.rb
```

Both designs pass. If you remove deduplication from either one, the retry tests fail.

The price is a `BigDecimal` on purpose. Pass a Float and every test errors, because `Float#round` doesn't accept a rounding mode.

## Requirements

Ruby 3.3 and minitest (bundled with Ruby). Nothing else.

## License

MIT
