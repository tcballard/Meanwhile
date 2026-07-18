# Meanwhile

Meanwhile is a macOS 14 menu-bar app that turns coding-agent wait time into one
small, actionable GitHub task. It is built in Swift 5.10 with no third-party
dependencies.

## v0.1.2 behavior

- Uses Claude Code and Codex lifecycle hooks—not process or CPU guesses—to track
  each session as `thinking`, `needs-you`, or `idle`.
- Shows an agent permission prompt immediately as **Needs you** and focuses its
  terminal session when clicked.
- Opens the wait-gate immediately while an agent is thinking. Idle agents
  always show glyph only.
- Surfaces two sources: failing CI on your own open pull requests, then review
  requests, oldest first within each source.
- Orders all work deterministically: needs-you, red CI, reviews, oldest first.
- Supports 15-minute snooze and **Hide Until It Changes** from the right-click
  menu.
- Renders the current item in the Claude Code status line when that slot is
  available.
- Tracks parallel Claude and Codex sessions independently and filters both
  GitHub sources using the repository settings.
- Offers a native **Launch at Login** switch that reflects macOS's real Login
  Items state, including approval when the system requires it.
- Shows the installed version and latest GitHub release in Settings without
  downloading or installing anything automatically.
- Identifies agent sessions that may be stuck and lets you clear only those
  sessions after confirmation.
- Copies a privacy-safe diagnostics report with coarse state, counts, and
  timestamps—never repository names, paths, prompts, session IDs, or
  credentials.

The wait-gate is the invariant: ordinary items never appear while no agent is
thinking.

## Requirements and setup

Authenticate the GitHub CLI first:

```sh
gh auth status
```

On first launch, Meanwhile opens Settings with integration health and one clear
**Install or Update…** action. The installer merges local hooks into
`~/.claude/settings.json` and `~/.codex/hooks.json` without replacing unrelated
settings. `CLAUDE_CONFIG_DIR` and `CODEX_HOME` are honored when set.
Tool-boundary hooks refresh active sessions, while active or blocked sessions
use a separate 24-hour crash-safety expiry. Settings flags non-idle sessions
that have not received an event for the configured stale interval and provides
an explicit recovery action. If Claude already has a custom status line,
Meanwhile preserves it and reports the conflict instead of overwriting it.

Codex may require one additional trust step: open `/hooks` in Codex and approve
the new Meanwhile hooks. Settings reports hook installation, GitHub
authentication, and the last agent event so setup failures are visible. Hook
events, the latest event, and a bounded recent-signals list stay on the Mac;
Meanwhile adds no telemetry. Launch at login uses macOS Service Management and
can be changed directly in Settings.

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

Repository selection, launch at login, the optional global shortcut, agent
integration installation, update visibility, diagnostics, and stuck-session
recovery are managed through **Settings…** in the right-click menu. Click the
shortcut recorder and press a modified letter, digit, Space, Tab, Return, or
Escape. The shortcut opens the current menu-bar item, the same as clicking the
status item.

Settings also explains the menu-bar language and keeps the five newest agent,
review, CI, snooze, hide, and installation signals visible for lightweight
diagnosis.

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

This produces `dist/Meanwhile-0.1.2-unsigned.zip` and `dist/meanwhile.rb`.
Publish the archive only as a GitHub **pre-release** tagged
`v0.1.2-unsigned`. The generated cask identifies it as unsigned and tells users
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
produces `dist/Meanwhile-0.1.2.zip` and `dist/meanwhile.rb`. It verifies the
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
