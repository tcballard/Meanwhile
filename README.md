# Meanwhile

Meanwhile is a macOS 14 menu-bar app that turns coding-agent wait time into one
small, actionable GitHub task. It is built in Swift 5.10 with no third-party
dependencies.

## v0.1 behavior

- Uses Claude Code and Codex lifecycle hooks—not process or CPU guesses—to track
  each session as `thinking`, `needs-you`, or `idle`.
- Shows an agent permission prompt immediately as **Needs you** and focuses its
  terminal session when clicked.
- Opens the wait-gate immediately while an agent is thinking. Idle agents
  always show glyph only.
- Surfaces two sources: failing CI on your own open pull requests, then review
  requests, oldest first within each source.
- Orders all work deterministically: needs-you, red CI, reviews, oldest first.
- Supports 15-minute snooze and dismiss from the right-click menu.
- Renders the current item in the Claude Code status line when that slot is
  available.
- Tracks parallel Claude and Codex sessions independently and filters both
  GitHub sources using the repository settings.

The wait-gate is the invariant: ordinary items never appear while no agent is
thinking.

## Requirements and setup

Authenticate the GitHub CLI first:

```sh
gh auth status
```

Launch Meanwhile, then approve **Install Agent Integrations** on first run (or
choose it later from the right-click menu). The installer merges local hooks
into `~/.claude/settings.json` and `~/.codex/hooks.json` without replacing
unrelated settings. `CLAUDE_CONFIG_DIR` and `CODEX_HOME` are honored when set.
Tool-boundary hooks refresh active sessions, while active or blocked sessions
use a separate 24-hour crash-safety expiry. If Claude already has a custom status line, Meanwhile
preserves it and reports the conflict instead of overwriting it.

Codex requires one additional trust step: open `/hooks` in Codex and approve the
new Meanwhile hooks. Hook events and presentation state stay on the Mac under
`~/Library/Application Support/Meanwhile`; Meanwhile adds no telemetry.

Terminal focus uses the terminal metadata captured with the agent working
directory. Terminal.app and iTerm sessions are selected by TTY; other supported
terminals fall back to activating the correct application.

## Build, test, and run

```sh
swift build
swift test
./Scripts/run-meanwhile.sh
```

The run script builds `dist/Meanwhile.app`, bundles the `MeanwhileHook` helper,
ad-hoc signs every executable and the app, verifies the bundle, and opens it.
`LSUIElement` keeps Meanwhile out of the Dock.

## Configuration

Optional configuration lives at `~/.config/peripheral/meanwhile.json`. Missing
fields retain their defaults:

```json
{
  "snoozeSeconds": 900,
  "sessionStaleSeconds": 3600,
  "activeSessionStaleSeconds": 86400,
  "enableReviews": true,
  "enableFailingCI": true
}
```

Repository selection remains in macOS user defaults and is managed through
**Settings…** in the right-click menu.

## GitHub access

Meanwhile uses only read-only `gh` commands. Review requests come from
`gh search prs --review-requested=@me`; failing CI comes from one GraphQL query
over the authenticated viewer's open pull requests and latest check rollups.
Results are cached for 60 seconds. Meanwhile never reads or stores a GitHub
token itself.

## Release and Homebrew

### Unsigned pre-release

Build an explicitly labelled, ad-hoc-signed pre-release and matching Homebrew
cask with:

```sh
GITHUB_REPOSITORY="tcballard/Meanwhile" ./Scripts/release-unsigned.sh
```

This produces `dist/Meanwhile-0.1.0-unsigned.zip` and `dist/meanwhile.rb`.
Publish the archive only as a GitHub **pre-release** tagged
`v0.1.0-unsigned`. The generated cask identifies it as unsigned and tells users
that Gatekeeper will block the first launch. Users who trust the build must
explicitly remove quarantine themselves; the cask does not bypass Gatekeeper.

### Signed release

Create a Developer ID signed, notarized release and matching Homebrew cask with:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
NOTARYTOOL_PROFILE="meanwhile-notary" \
GITHUB_REPOSITORY="owner/Meanwhile" \
./Scripts/release.sh
```

The script builds and signs the app in a temporary local directory, then
produces `dist/Meanwhile-0.1.0.zip` and `dist/meanwhile.rb`. It verifies the
stapled app and a clean extraction of the final archive before returning.
Publishing the archive, cask, and GitHub release remains an explicit
release-owner action. Set `RELEASE_OUTPUT_DIR` to write the final artifacts
somewhere other than `dist`.

## Package layout

- `Peripheral`: reusable macOS status-item, polling, shell, configuration, and
  launch-agent plumbing.
- `MeanwhileCore`: event state, wait-gating, GitHub sources, ordering,
  dispositions, terminal focus, and integration installation.
- `Meanwhile`: the menu-bar executable.
- `MeanwhileHook`: the Claude/Codex hook and Claude status-line helper.

See [ROADMAP.md](ROADMAP.md) for the release gate and post-v0.1 decision rule.
