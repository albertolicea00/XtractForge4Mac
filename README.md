# XtractForge4Mac
A powerful, modern and modular media engine capable of downloading, extracting and processing content through multiple CLI‑based workflows.

Native macOS app (Swift + SwiftUI, single window). Drop or paste a link —
video, audio, gallery, stream, or direct file — and XtractForge routes it to
the right tool and downloads it.

Bundled tools (install the ones you use): [yt-dlp](https://github.com/yt-dlp/yt-dlp),
[lux](https://github.com/iawia002/lux), [gallery-dl](https://github.com/mikf/gallery-dl),
[spotDL](https://github.com/spotDL/spotify-downloader), [FFmpeg](https://ffmpeg.org),
and curl.

```bash
brew install yt-dlp ffmpeg gallery-dl lux && pip install spotdl
```

## Build & run

Requires Xcode 15+ / macOS 14+.

```bash
swift build              # debug build
swift run XtractForge    # run the app
swift test               # unit tests
scripts/make-app.sh      # assemble dist/XtractForge.app (release)
```

Note: completion notifications only fire when running from the `.app` bundle
(bare `swift run` executables have no bundle identifier).

## Development

See [CLAUDE.md](CLAUDE.md) for architecture, scope rules, and contribution
conventions.
