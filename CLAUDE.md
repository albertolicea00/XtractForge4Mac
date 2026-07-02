# XtractForge for Mac — Agent & Developer Documentation

Native macOS media downloader. Swift + SwiftUI, no web stack. This is a ground-up
native rewrite of the old Tauri app (see `../old/` for reference only — do not copy
its architecture, plugin system, or theme system).

---

## Product Scope

One-window app. The user gets media onto their machine in three gestures:

1. **Drag & drop** a URL (or text containing URLs) onto the window.
2. **Paste** (⌘V anywhere in the window, or the paste button).
3. That's it. Info is fetched, options shown inline, download queued.

Everything else (settings, queue, history) lives inside that same window or the
standard macOS Settings scene (⌘,). No tabs-and-sidebar shell like the old app.

### Explicitly out of scope (do NOT build unless asked)

- **No plugin system.** Downloaders are compiled in. Adding one = code change + app update.
  Never add dynamic loading of `.js`/scripts/bundles.
- **No theme system.** Appearance is System / Light / Dark only, via native
  `preferredColorScheme` / `NSApp.appearance`. No custom colors, no CSS-like variables,
  no accent overrides beyond the OS accent color.
- **No remote intake yet.** Chrome extension, Telegram bot, and mobile-sync intake are
  planned future features. The only forward-compat allowance: keep URL intake funneled
  through a single `IntakeService.submit(url:)` entry point so a `xtractforge://` URL
  scheme handler can be added later without refactoring. Do not implement the scheme,
  server, or any sync now.

---

## Tech Stack

- Swift 5.10+, SwiftUI (AppKit interop where needed), macOS 14+ target.
- Swift Package (`Package.swift`) — no `.xcodeproj` checked in; `swift build` /
  `swift test` from the CLI, or open the package in Xcode. Zero third-party
  dependencies.
- Child processes via `Foundation.Process`; async/await + `AsyncStream` for
  stdout/stderr line streaming.
- Tests: XCTest against `XtractForgeCore` (all pure logic lives there).

## Project Layout

Two targets: `XtractForgeCore` (library — models, downloaders, engine; no UI,
fully testable) and `XtractForge` (executable — SwiftUI app importing Core).

```
Package.swift
Sources/XtractForgeCore/
├── Models/                     # Models.swift (MediaInfo, Command, OptionField, …), AppSettings.swift
├── Downloaders/
│   ├── Downloader.swift        # the protocol + DownloaderRegistry (fixed array, routing order)
│   ├── YtDlp.swift, Lux.swift, GalleryDl.swift, SpotDl.swift, FFmpeg.swift, Curl.swift
├── Engine/
│   ├── DownloadManager.swift   # @Observable queue state + DownloadItem; owns all tasks
│   ├── ProcessRunner.swift     # Process wrapper: spawn, stream lines, suspend/resume/terminate
│   ├── Staging.swift           # temp-dir staging + move-on-success + organize
│   └── Intake.swift            # pure URL extraction from dropped/pasted text
└── Support/                    # Regex.swift helper
Sources/XtractForge/
├── XtractForgeApp.swift        # @main — Window scene, Settings scene, Commands (menu bar)
├── SettingsStore.swift         # @Observable AppSettings wrapper persisted to UserDefaults
├── Views/                      # MainView, DropZoneView, DownloadRowView, OptionsSheet, SettingsView
└── Support/AppServices.swift   # IntakeService (single URL entry point), notifications, appearance
Tests/XtractForgeCoreTests/     # routing, arg-building, progress parsing, staging, intake
scripts/make-app.sh             # assembles dist/XtractForge.app from the release build
```

## Downloader Protocol (fixed, compiled-in)

```swift
protocol Downloader {
    var id: String { get }              // "yt-dlp", "lux", "gallery-dl", "spotdl", "ffmpeg", "curl"
    var name: String { get }
    var binaryDefault: String { get }   // overridable path in Settings
    var installHint: String { get }     // e.g. "brew install yt-dlp"

    func checkDependency(settings: AppSettings) async -> DependencyStatus // runs `--version`
    func canHandle(_ url: URL) -> Bool
    func getInfo(_ url: URL, settings: AppSettings) async throws -> MediaInfo
    func buildArgs(_ url: URL, options: DownloadOptions, settings: AppSettings) -> Command // binary + args
    func parseProgress(_ line: String) -> ProgressUpdate?
}
```

**Routing** (`DownloaderRegistry.route(url:)`): first match wins, most specific first —
`spotdl → gallery-dl → lux → ffmpeg → curl → yt-dlp`. yt-dlp's `canHandle` always
returns `true` (catch-all). Downloaders disabled in Settings are skipped.
Each downloader's URL matching, arg building, and progress-line regexes are ported
from `../old/src/plugins/*.ts`. One deliberate deviation: lux no longer claims
youtube.com/youtu.be/twitter/x/instagram — YouTube belongs to yt-dlp, and
twitter/instagram were already captured by gallery-dl (which precedes lux).

**Per-download options:** `MediaInfo` may carry an option schema (format/quality/audio-only
etc., same idea as old `_downloadOptions`) rendered by `OptionsSheet`; simple sources set
`simpleDownload = true` and skip the sheet.

## Download Engine

- `DownloadManager` is the single source of truth for the queue (`@Observable`,
  main-actor state, background work in tasks).
- **Staging** (default on): child process runs in
  `<downloadFolder>/.xtractforge-tmp/<urlHash>/`. Exit 0 → move files to final folder
  applying `organize` (`none | type | source`), delete temp dir. Failure → leave temp
  dir in place so the tool can resume later.
- **Pause/Resume:** SIGSTOP / SIGCONT on the process group. **Cancel:** SIGTERM, then
  SIGKILL after a grace period.
- Progress: stream stdout/stderr lines → owning downloader's `parseProgress` →
  queue-row UI update. Throttle UI updates (~10/s max).
- Completion: user notification (UserNotifications) + "Reveal in Finder" action.

## Settings (UserDefaults via @AppStorage / Codable blob)

Keys mirror the old `config.json` where still relevant:
`downloadFolder`, `speedLimit`, `embedSubtitles`, `sponsorBlock`, `stageToTemp`,
`organize`, `disabledDownloaders[]`, per-downloader binary paths and options
(`luxMultiThread`, `spotdlFormat`, `spotdlBitrate`, `galleryDlCookies`, …),
`appearance` (`system | light | dark`), `watchClipboard` (opt-in: offer clipboard URL
on app activation).

## Native Integration (this is the point of the rewrite)

- **Menu bar** via SwiftUI `Commands`: File (Paste URL ⇧⌘V, Open Downloads Folder ⇧⌘O,
  Clear Finished ⇧⌘K), standard Edit menu, Window, Help, About panel. Settings under
  the app menu (⌘,). (⇧⌘V, not ⌘V — plain ⌘V stays reserved for text-field paste.)
- Standard macOS behaviors: drag & drop via `.dropDestination(for:)`, Services-friendly
  paste, Dock badge with active download count, App Nap disabled while downloading
  (`ProcessInfo.beginActivity`).
- Appearance follows the system by default; Light/Dark force via
  `NSApp.appearance = NSAppearance(named:)`. Use system materials, SF Symbols, standard
  controls — no custom chrome, no custom colors.
- Sandbox note: the app shells out to user-installed binaries (Homebrew paths like
  `/opt/homebrew/bin`) — App Sandbox must stay **off** (Developer ID + notarization
  distribution, not Mac App Store).

## Development Workflow

```bash
swift build               # debug build
swift run XtractForge     # run the app (no bundle → notifications disabled)
swift test                # run unit tests
scripts/make-app.sh       # assemble dist/XtractForge.app (release, ad-hoc signed)
```

- Distribution: Developer ID signed + notarized `.dmg` (scripted later; not set up yet).
- Run tests after every commit; suite must be green before any push.

## Git Rules

- **Conventional Commits** (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`),
  imperative, ≤72-char subject. Commit in small meaningful units as you work.
- **No co-author trailers.** Never add `Co-Authored-By` or any generated-with footer.
- Never push, tag, or release unless explicitly asked. Commits stay local.
