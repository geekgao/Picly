
<p align="center">
<h1 align="center">Picly</h1>
<h3 align="center">Waterfall-style Image Viewer for macOS<br><br><a href="./README_zh.md">[中文说明]</a></h3> 
</p>

[![](https://img.shields.io/github/release/netdcy/Picly.svg?color=blue)](https://github.com/netdcy/Picly/releases/latest "GitHub release") [![](https://img.shields.io/github/downloads/netdcy/Picly/total?color=blue)](https://github.com/netdcy/Picly/releases/latest "GitHub downloads") ![GitHub License](https://img.shields.io/github/license/netdcy/Picly?color=blue)

## Screenshots

### Light Mode
![preview](https://netdcy.github.io/Picly/docs/preview_2.png)

### Dark Mode
![preview](https://netdcy.github.io/Picly/docs/preview_1.png)

## Features:
 - Adaptive layout mode, light/dark mode
 - Convenient file management (similar to Finder)
 - Right-click gestures, quickly find the previous/next folder with images/videos
 - Performance optimizations for directories with a large number of images
 - High-quality scaling (reduces moiré and other issues)
 - Support for video playback
 - Support for HDR display
 - Recursive mode

## Installation and Usage

### System Requirements

 - macOS 11.0 or Later

### Privacy and Security

 - Open source
 - No Internet connection

### Homebrew Install

Initial Installation
```
brew install picly
```
Upgrade
```
brew update
brew upgrade picly
```

## Instructions:
### In Image View:
 - Double-click to open/close the image
 - Hold down the right/left mouse button and scroll the wheel to zoom
 - Hold down the middle mouse button and drag to move the window
 - Long press the left mouse button to switch to 100% zoom
 - Long press the right mouse button to fit the image to the view
### Right-Click Gestures:
 - Right/Left: Switch to the next/previous folder with images/videos (logically equivalent to the next folder when sorting all folders on the disk)
 - Up: Switch to the parent directory
 - Down: Return to the previous directory
 - Up-Right: Switch to the next folder with images at the same level as the current folder
 - Down-Right: Close the tab/window
### Keyboard Shortcuts:
 - W: Same as the right-click gesture Up
 - A/D: Same as the right-click gesture Left/Right
 - S: Same as the right-click gesture Down

## Performance Optimizations

Picly incorporates several optimizations to handle directories with thousands of files smoothly, especially on external exFAT drives and network volumes.

### File Metadata Cache (`DirMetadataCache`)

Persistent on-disk cache of `[filename: (fileSize, modDate)]` per directory. On subsequent opens of the same folder, only new or changed files are re-read — unchanged files skip the entire scan (no I/O). Cache is stored at `~/Library/Application Support/Picly/DirMetadataCache.json`.

### Fast JPEG/PNG Header Processing

Instead of creating a full `CGImageSource` (which reads extensive file metadata), image dimensions are extracted directly from the file header:
- **JPEG/PNG**: reads first 8KB/33 bytes, parses SOF/IHDR markers for pixel dimensions and EXIF orientation.
- Impact: per-image I/O reduced from ~16KB to ~8KB for JPEG, 33 bytes for PNG.

### Video Optimization

Video dimensions prioritized via **ffprobe** (reads only the moov box header) instead of `AVAsset(url:)` (which parses more container metadata). Falls back to `AVAsset` if ffprobe is unavailable.

### Parallel Processing

Background task concurrency increased:
- **Internal SSD**: up to 8 concurrent operations for both image size reading and thumbnail generation.
- **External drives**: up to 4 concurrent operations (configurable in Advanced Settings).

### Reduced I/O for External Volumes

On exFAT/NAS drives, redundant file property requests are eliminated:
- Fixed duplicate `resourceValues(forKeys:)` call for Finder tags (was reading tags twice per file — 8,680 extra I/Os for a folder with 8,500 images + 180 videos).
- `.isSymbolicLinkKey` and iCloud keys removed from external volume property fetch.

### Progressive Loading & Real-Time Layout Updates

- Items appear in the collection view within **~500ms** (as soon as their file properties are scanned), with correct aspect ratios updated in real-time as each batch finishes processing.
- Layout is invalidated after each batch of size calculations, so visible items immediately snap to their correct dimensions.
- Thumbnail images load asynchronously and replace placeholders progressively.

### Scroll Position Preservation

When new files are detected via `DispatchSource` file system events, the scroll position is saved before refresh and restored afterward — preventing the view from jumping to newly added files.

## Build

### Environment

Xcode 15.2+

### Libraries

 - https://github.com/arthenica/ffmpeg-kit
 - https://github.com/attaswift/BTree
 - https://github.com/sindresorhus/Settings

### Steps

1. Clone the source code of the project and libraries.
2. For ffmpeg-kit, it need to be built to binary first. If you want to save time, you can directly download its pre-built binary, named like `ffmpeg-kit-full-gpl-6.0-macos-xcframework.zip` (not LTS version). Unzip it, then execute this in terminal to remove its quarantine attribute:

    ```
    sudo xattr -rd com.apple.quarantine ./ffmpeg-kit-full-gpl-6.0-macos-xcframework
    ```
    
    (Due to the project being discontinued and copyright reasons, the prebuilt binaries have been removed. Here is a [backup](https://github.com/netdcy/ffmpeg-kit/releases/download/v6.0/ffmpeg-kit-full-gpl-6.0-macos-xcframework.zip) of original file.)

3. Organize the directory structure as shown below:

    ```
    ├── Picly
    │   ├── Picly.xcodeproj
    │   └── Picly
    │       └── Sources
    ├── ffmpeg-kit-build
    │   └── bundle-apple-xcframework-macos
    │       ├── ffmpegkit.xcframework
    │       └── ...
    ├── BTree
    │   ├── Package.swift
    │   └── Sources
    └── Settings
        ├── Package.swift
        └── Sources
    ```

4. Open `Picly.xcodeproj` by Xcode, click 'Product' -> 'Build For' -> 'Profiling' in menu bar.
5. Then 'Product' -> 'Show Build Folder in Finder', and you will find the app is at `Products/Release/Picly.app`.

## Donate

If you found the project is helpful, feel free to buy me a coffee.

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/netdcyn)

<img src="https://picly.app/donate.jpg" alt="WeChat Donate" width="350"/>

## License

This project is licensed under the GPL License. See the [LICENSE](https://github.com/netdcy/Picly/blob/main/LICENSE) file for the full license text.

