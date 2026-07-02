import Foundation
import CoreServices

actor DirectoryWatcher {
    static let shared = DirectoryWatcher()

    private var stream: FSEventStreamRef?
    private var isWatching = false
    private var pendingChanges = Set<String>()
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 3.0
    private let imageAI = ImageAIService.shared

    private let supportedExts: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"
    ]

    func start(watching paths: [String]) {
        guard !isWatching, !paths.isEmpty else { return }
        isWatching = true

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let cfPaths = paths.map { $0 as CFString } as CFArray
        let latency: CFTimeInterval = 1.0

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPaths, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
                if let paths = eventPaths as? [String] {
                    Task { await watcher.handleEvents(paths: paths) }
                }
            },
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream = stream else {
            log("DirectoryWatcher: failed to create stream")
            isWatching = false
            return
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        log("DirectoryWatcher: started watching \(paths.count) paths")
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        isWatching = false
        debounceTask?.cancel()
        pendingChanges.removeAll()
        log("DirectoryWatcher: stopped")
    }

    var isActive: Bool { isWatching }

    private func handleEvents(paths: [String]) {
        for eventPath in paths {
            let url = URL(fileURLWithPath: eventPath)
            let ext = url.pathExtension.lowercased()
            guard supportedExts.contains(ext) else { continue }
            if url.lastPathComponent.hasPrefix(".") { continue }
            pendingChanges.insert(eventPath)
        }

        guard !pendingChanges.isEmpty else { return }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            if Task.isCancelled { return }
            await self.flushChanges()
        }
    }

    private func flushChanges() async {
        let batch = pendingChanges
        pendingChanges.removeAll()

        let fm = FileManager.default
        for path in batch {
            if Task.isCancelled { return }
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: path, isDirectory: &isDir)

            if exists && !isDir.boolValue {
                do {
                    try await imageAI.indexFile(path: path)
                    log("DirectoryWatcher: indexed \(path)")
                } catch {
                    log("DirectoryWatcher: index failed \(path): \(error.localizedDescription)")
                }
            } else if !exists {
                do {
                    try await imageAI.deleteImage(path: path)
                    log("DirectoryWatcher: deleted \(path)")
                } catch {
                    log("DirectoryWatcher: delete failed \(path): \(error.localizedDescription)")
                }
            }
        }
    }

}
