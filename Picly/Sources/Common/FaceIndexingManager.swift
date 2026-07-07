import Foundation
import Cocoa

class FaceIndexedCache {
    static let shared = FaceIndexedCache()

    private var cache: [String: TimeInterval] = [:]
    private let url: URL
    private var dirty = false
    private let lock = NSLock()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Picly", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("FaceIndexedCache.json")
        load()
        NotificationCenter.default.addObserver(self, selector: #selector(saveToDisk), name: NSApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveToDisk), name: NSApplication.didResignActiveNotification, object: nil)
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.saveToDisk()
        }
    }

    func isIndexed(path: String, modDate: Date) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let cachedTime = cache[path] else { return false }
        return cachedTime == modDate.timeIntervalSince1970
    }

    func markIndexed(path: String, modDate: Date) {
        lock.lock(); defer { lock.unlock() }
        cache[path] = modDate.timeIntervalSince1970
        dirty = true
    }

    /// Clear all entries. Triggers an immediate disk write.
    func clearAll() {
        lock.lock()
        cache.removeAll()
        dirty = true
        lock.unlock()
        saveToDisk()
    }

    @objc private func saveToDisk() {
        lock.lock()
        guard dirty else { lock.unlock(); return }
        let snapshot = cache
        dirty = false
        lock.unlock()
        do {
            let data = try JSONSerialization.data(withJSONObject: snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            log("FaceIndexedCache: save failed \(error.localizedDescription)")
        }
    }

    private func load() {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: TimeInterval]
        else { return }
        cache = dict
    }
}

actor FaceIndexingManager {
    static let shared = FaceIndexingManager()

    private let faceService = FaceService.shared
    private let imageAI = ImageAIService.shared
    private let cache = FaceIndexedCache.shared

    private var _isIndexing = false
    private var _indexedDone = 0
    private var _indexedTotal = 0

    private var onProgress: ((Int, Int) -> Void)?

    private init() {}

    var isBusy: Bool { _isIndexing }
    var currentProgress: (done: Int, total: Int) { (_indexedDone, _indexedTotal) }

    func indexPhoto(_ path: String) async -> Bool {
        guard globalVar.imageAIEnabled else { return false }
        guard !Task.isCancelled else { return false }
        guard FileManager.default.fileExists(atPath: path) else {
            log("FaceIndexer: file not found: \(path.prefix(80))")
            return false
        }

        let url = URL(fileURLWithPath: path)
        let currentModDate: Date
        if let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
           let modDate = attrs.contentModificationDate {
            currentModDate = modDate
        } else {
            currentModDate = Date(timeIntervalSince1970: 0)
        }

        if cache.isIndexed(path: path, modDate: currentModDate) {
            return false
        }

        do {
            try await faceService.indexFaces(path: path)
            cache.markIndexed(path: path, modDate: currentModDate)
            log("FaceIndexer: indexed \(String(path.prefix(80)))")
            return true
        } catch {
            log("FaceIndexer: failed \(String(path.prefix(80))): \(error.localizedDescription)")
            return false
        }
    }

    func indexPhotos(_ paths: [String], onProgress: ((Int, Int) -> Void)? = nil) async {
        guard globalVar.imageAIEnabled else { return }
        guard !paths.isEmpty else { return }
        _isIndexing = true
        _indexedDone = 0
        _indexedTotal = paths.count
        self.onProgress = onProgress
        defer {
            _isIndexing = false
            self.onProgress = nil
        }

        let total = paths.count
        for (i, path) in paths.enumerated() {
            guard !Task.isCancelled else { break }
            _ = await indexPhoto(path)
            _indexedDone = i + 1
            let done = _indexedDone
            if done % 5 == 0 || done == total {
                onProgress?(done, total)
            }
        }
    }

    func indexPhotosBatch(_ paths: [String], onProgress: ((Int, Int) -> Void)? = nil) async {
        guard globalVar.imageAIEnabled else { return }
        await indexPhotos(paths, onProgress: onProgress)
    }

    func attachProgress(_ onProgress: @escaping (Int, Int) -> Void) {
        self.onProgress = onProgress
        if _isIndexing {
            onProgress(_indexedDone, _indexedTotal)
        }
    }

    func removePhoto(_ path: String) async {
        guard globalVar.imageAIEnabled else { return }
        log("FaceIndexer: removal queued for \(path)")
    }
}
