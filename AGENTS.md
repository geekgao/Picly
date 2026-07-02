# AGENTS.md — Picly

macOS waterfall-style image viewer. Cocoa/AppKit, Swift 5.0, macOS 12.0+.

## Build

- **Xcode 15.2+ required.** No command-line build — open `Picly.xcodeproj` in Xcode.
- **Release build:** `Product → Build For → Profiling`; app at `Products/Release/Picly.app`.
- **Bundle IDs:** Debug=`netdcy.PiclyDbg`, Release=`netdcy.Picly`.
- **Scheme env** (`Picly.xcscheme`): `OS_ACTIVITY_MODE=disable`, `IDELogRedirectionPolicy=oslogToStdio`.

### External dependencies (sibling directories, not SPM-managed)

```
├── Picly/
├── ffmpeg-kit-build/bundle-apple-xcframework-macos/  (prebuilt .xcframework)
├── BTree/                                             (SwiftPM)
└── Settings/                                          (SwiftPM)
```

ffmpeg-kit binary must have quarantine removed:
```bash
sudo xattr -rd com.apple.quarantine ./ffmpeg-kit-full-gpl-6.0-macos-xcframework
```

### Local development flag

Copy `LocalDev.xcconfig.template` → `LocalDev.xcconfig` (gitignored) to enable `LOCAL_DEV` compilation condition:
```bash
cp LocalDev.xcconfig.template LocalDev.xcconfig
```
Guards in code: `#if LOCAL_DEV`, `#if DEBUG && LOCAL_DEV`.

## Architecture

- **Entry:** `Sources/AppDelegate.swift` (`@main`).
- **Window:** `Sources/WindowController.swift` — toolbar, titlebar, full-screen.
- **Main VC:** `Sources/ViewController.swift` (~2500 lines) — owns layout, sidebar, thumbnails, large image.
- **Extensions:** `Sources/ViewControllerExtension/` — ~15 files splitting VC logic (dir tree, file ops, gestures, shortcuts, etc.).
- **Views:** `Sources/Views/` — custom NSView subclasses (collection/outline/split/image views, etc.).
- **Common:** `Sources/Common/` — shared utilities, enums, data model, FFmpeg/video helpers.
- **Settings:** `Sources/SettingsViews/` — settings panes via `Settings` SPM library; xib-based UI.
- **Localization:** Xcode 15+ String Catalog (`.xcstrings`) in `Resources/mul.lproj/` and `SettingsViews/mul.lproj/`.

## Testing, CI, Linting

- **No test targets** exist in the project.
- **No CI/CD** (no GitHub Actions workflows).
- **No linting/formatter config** (no SwiftLint, SwiftFormat, etc.).
- `xcodebuild` from CLI may work but is not the intended workflow.

## Conventions

- Thread-safety via `@Atomic` property wrapper (`Common.swift`) and custom `MyTimer`.
- `globalVar` / `tempVar` singletons for global and ephemeral state.
- `.xcstrings` for localization (Xcode 15+).
