# Contributing to XtractForge for Mac

Thanks for helping forge a better downloader. This document covers workflow and
ground rules; architecture lives in [CLAUDE.md](CLAUDE.md), design rationale in
[DESIGN.md](DESIGN.md).

## Prerequisites

- macOS 14+ and Xcode 15+ (Swift 5.10 toolchain or newer)
- The tools you want to test against: `brew install yt-dlp ffmpeg gallery-dl lux`,
  `pip install spotdl`

## Build, run, test

```bash
swift build              # debug build
swift run XtractForge    # run the app
swift test               # unit tests — must be green before every PR
scripts/make-app.sh      # assemble dist/XtractForge.app
```

## Ground rules (scope)

These are deliberate product decisions, not oversights — PRs that reverse them
will be declined:

- **No plugin system.** Downloaders are compiled in. Adding one is a code change
  that ships with a release.
- **No theme system.** Appearance is System / Light / Dark via native APIs only.
- **One window.** No sidebars, tabs, or dashboards.
- **Zero third-party dependencies.** Foundation + SwiftUI + the standard library.

## Adding or changing a downloader

1. Implement the `Downloader` protocol in `Sources/XtractForgeCore/Downloaders/`.
2. Register it in `DownloaderRegistry.all` **before** yt-dlp (the catch-all stays last).
3. Cover `canHandle`, `buildArgs`, and `parseProgress` with tests in
   `Tests/XtractForgeCoreTests/` — use real output lines from the tool.
4. Update the Settings → Downloaders section if the tool has options.

## Commits & PRs

- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
  Imperative mood, ≤72-char subject, body explains *why* when it isn't obvious.
- Small, focused PRs. One logical change per PR.
- `swift test` green is a hard requirement; add tests for anything with logic.
- Fill in the PR template; link related issues.

## Reporting bugs / requesting features

Use the issue templates. For bugs, include macOS version, tool versions
(`yt-dlp --version` etc.), the URL type (not necessarily the URL), and the
failing output line if visible.

## Code of Conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). Be excellent
to each other.
