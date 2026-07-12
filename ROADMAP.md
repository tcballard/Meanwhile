# Meanwhile roadmap

This is a decision tool, not a backlog.

## Product rules

**The wait-gate is the product.** No thinking agent means glyph only. A
`needs-you` event may preempt the gate, but ordinary work never appears while
the user is typing.

Sources must be glance-actionable in roughly 10 seconds. Ordering is fixed:
needs-you, failing CI, reviews, then oldest first. `Peripheral` is already an
extracted package target.

## v0.1 — Product cut

**Scope:** Event-driven Claude and Codex session states, needs-you preemption,
Claude status-line output, 10-second debounce, snooze/dismiss, failing CI and
review sources, focus follow, parallel-session awareness, configuration,
signed packaging, notarization tooling, and generated Homebrew cask metadata.

**Stable release gate:** Publish a stable release only after the automated tests and strict bundle
signature verification pass, the hook installer is exercised against clean and
existing Claude/Codex settings, and a real agent permission prompt focuses the
correct terminal. Developer ID notarization and a release-host URL must exist
before the stable public archive or cask is published. An earlier testing build
may be distributed only when its tag, GitHub release, archive, and Homebrew cask
all identify it clearly as an unsigned pre-release.

**Stop condition:** If a week of real self-use does not produce repeated
glances and measurable review/CI clearance, stop at v0.1 and do not manufacture
another source.

## Beyond v0.1

There is no scheduled v0.2. More work earns time only after external users
return in multiple weeks and request a specific change. Re-cost Meanwhile
against the rest of the portfolio before accepting that work.
