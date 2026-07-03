# XtractForge for Mac — Design

## North Star: "The Invisible Forge"

The old XtractForge chased a "Cyber-Glass" identity — custom palettes, glassmorphism,
themable everything. This app deliberately goes the other way: **it should look and
feel like Apple shipped it.** No custom chrome, no brand color, no theme engine.
The design *is* macOS; XtractForge's personality lives in how little it asks of you.

## Experience Principles

1. **Three gestures, one window.** Drop a link, paste a link, or accept the clipboard
   suggestion. Everything else — queue, progress, results — happens in the same window.
2. **The OS owns the pixels.** System materials, SF Symbols, standard controls, the
   user's accent color. Appearance is System / Light / Dark, nothing else.
3. **Progress you can trust.** Real tool output drives the UI (percent, speed, ETA
   parsed from each tool's stdout). No fake progress bars.
4. **Fail soft, resume later.** Staged downloads mean a failed or paused download
   never litters the Downloads folder; the temp dir survives so tools can resume.
5. **Quiet by default.** One notification on completion or failure. Dock badge counts
   active downloads. Nothing else interrupts.

## The One Screen

```
┌────────────────────────────────────────────┐
│  ⌄ Drop a link to download                 │   ← drop zone (dashed, calm)
│    video · audio · galleries · streams     │
├────────────────────────────────────────────┤
│  🔗 Link on clipboard   [Download] [×]     │   ← opt-in clipboard suggestion
├────────────────────────────────────────────┤
│  ⬇ Big Buck Bunny — 42% · 3.2MiB/s · 0:42  │   ← queue rows: icon, title,
│  ✓ Artist - Song.mp3   ~/Downloads         │      progress, inline actions
│  ⚠ Failed clip         [retry] [remove]    │
└────────────────────────────────────────────┘
```

- **Options sheet** appears only when a download has real choices (format/quality);
  simple sources (galleries, Spotify) skip straight to downloading.
- **Settings** live in the standard macOS Settings scene (⌘,): General, Downloaders,
  Appearance.
- **Menu bar** carries the app verbs: Paste URL ⇧⌘V, Open Downloads Folder ⇧⌘O,
  Clear Finished ⇧⌘K.

## Typography & Color

System all the way down: SF Pro via standard text styles, monospaced digits where
numbers tick (progress), semantic colors only (`.secondary`, `.green`, `.red`,
accent). If a design choice needs a hex code, it's wrong for this app.

## Anti-Goals

- No sidebar/tab shell, no dashboard density. One screen.
- No theme system, no accent overrides, no glassmorphism.
- No plugin marketplace UI. Six tools, compiled in.
- No progress theater — if a tool reports nothing, show an indeterminate bar.

## Code Structure

Two SPM targets: `XtractForgeCore` (models, downloaders, engine — pure, tested)
and `XtractForge` (SwiftUI app). See [CLAUDE.md](CLAUDE.md) for the full map.
