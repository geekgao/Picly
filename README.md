<p align="center">
<h1 align="center">Picly</h1>
<h3 align="center">Waterfall-style Image Viewer for macOS — Enhanced Fork<br><br><a href="./README_zh.md">[中文说明]</a></h3> 
</p>

A feature-rich fork of [netdcy/Picly](https://github.com/netdcy/Picly), the macOS waterfall-style image viewer, with AI-powered search, geographic location filtering, natural language queries, image conversion, and extensive performance optimizations for external volumes.

## Additional Features

### AI Semantic Search
Integrates an on-device AI server (`imageai`) that indexes and searches images by semantic content. Supports natural language queries like "sunset at the beach" or "red car".

### Geographic Location Search
- **GPS Indexing**: Extracts EXIF GPS coordinates from images and builds a searchable geo index.
- **Proximity Search**: Find all photos taken near a specific location using natural language (e.g., "near Tokyo", "photos in Paris") with configurable radius.
- **Reverse Geocoding**: Uses CLGeocoder with retry/timeout logic for reliable place name resolution; falls back to MKLocalSearch and built-in country center coordinates.
- **Geo Filter**: Filter the current folder to show only photos matching a geographic query, with count display.

### Natural Language Search
Search with date, location, and keyword filters in a single query:
- Date ranges: "photos from last week", "March 2024"
- Location: "near Shanghai", "in Japan"
- Keyword: "birthday party", "document"
- Combined: "photos near Tokyo taken in January"

### Image Conversion
Convert images between formats (JPEG, PNG, WebP) with options for quality, resizing, and output directory. Supports batch conversion via the UI or right-click context menu.

### External Volume Optimization
Dramatically reduces I/O on exFAT, FAT32, and network drives:
- Lazy property reads — file dates/sizes are fetched only when the current sort mode requires them
- Eliminated redundant `resourceValues(forKeys:)` calls (Finder tags were read twice per file)
- Stripped `.isSymbolicLinkKey` and iCloud properties from external volume fetches
- Configurable concurrency (up to 8 for internal SSD, up to 4 for external)

### File Metadata Cache (`DirMetadataCache`)
Persistent on-disk cache of `[filename: (fileSize, modDate)]` per directory. On subsequent opens, only new or changed files trigger I/O — unchanged files skip the scan entirely. Cache stored at `~/Library/Application Support/Picly/DirMetadataCache.json`.

### TaskPool — Structured Concurrency
Custom thread pool for background tasks:
- Fixed-size worker threads with blocking-safe queue
- Priority queuing (thumbnail loading prioritized over dimension reading)
- Graceful cancellation on directory change

### EnhancedIndex — File Tracking
Tracks file creation, deletion, and moves across sessions. Used for maintaining AI index consistency and geo cache accuracy when files are moved externally.

### Additional Improvements
- **ImageAI Models Panel**: View AI indexing status, model loading, and per-file analysis results
- **Favorites Popover**: Quick-access favorites with search
- **File Info Window**: Detailed metadata viewer
- **Finder Tag Integration**: Read and filter by Finder tags
- **ConvertProcess**: FFmpeg-based image format conversion pipeline
- **Waterfall/Justified/Grid Layout Toggle**: Switch layouts with a toolbar button
- **Layout Profiles**: Save and restore layout configurations
- **Scroll Position Preservation**: Maintain scroll position when FSEvents trigger refreshes
- **Progressive Loading**: Items appear in ~500ms with real-time aspect ratio updates

## Build

### Environment

Xcode 15.2+, macOS 12.0+

### Dependencies

- [ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit) — video processing
- [BTree](https://github.com/attaswift/BTree) — sorted collections
- [Settings](https://github.com/sindresorhus/Settings) — settings pane

### Steps

1. Clone this repository and the dependency libraries into sibling directories.
2. For ffmpeg-kit, build to binary first or download the pre-built xcframework:
   ```
   sudo xattr -rd com.apple.quarantine ./ffmpeg-kit-full-gpl-6.0-macos-xcframework
   ```
3. Organize directory structure:
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
4. Open `Picly.xcodeproj` in Xcode, select `Product → Build For → Profiling`.
5. Find the built app at `Products/Release/Picly.app`.

## License

GPL License. See [LICENSE](LICENSE) for details.
