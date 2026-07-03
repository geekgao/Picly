import Foundation

actor FaceIndexingManager {
    static let shared = FaceIndexingManager()

    private let faceService = FaceService.shared
    private let imageAI = ImageAIService.shared

    private var isIndexing = false

    private init() {}

    var isBusy: Bool { isIndexing }

    func indexPhoto(_ path: String) async {
        guard globalVar.imageAIEnabled else { return }
        guard FileManager.default.fileExists(atPath: path) else {
            log("FaceIndexer: file not found: \(path.prefix(80))")
            return
        }
        do {
            try await faceService.indexFaces(path: path)
            log("FaceIndexer: indexed \(String(path.prefix(80)))")
        } catch {
            log("FaceIndexer: failed \(String(path.prefix(80))): \(error.localizedDescription)")
        }
    }

    func indexPhotos(_ paths: [String], onProgress: ((Int, Int) -> Void)? = nil) async {
        guard globalVar.imageAIEnabled else { return }
        guard !paths.isEmpty else { return }
        isIndexing = true
        defer { isIndexing = false }

        let total = paths.count
        var completed = 0
        let lock = NSLock()
        let batchSize = 4  // Limit concurrency to avoid overwhelming the server

        for start in stride(from: 0, to: paths.count, by: batchSize) {
            let batch = Array(paths[start..<min(start + batchSize, paths.count)])
            await withTaskGroup(of: Void.self) { group in
                for path in batch {
                    group.addTask {
                        await self.indexPhoto(path)
                        lock.lock()
                        completed += 1
                        let done = completed
                        lock.unlock()
                        onProgress?(done, total)
                    }
                }
            }
        }
    }

    func indexPhotosBatch(_ paths: [String], onProgress: ((Int, Int) -> Void)? = nil) async {
        guard globalVar.imageAIEnabled else { return }
        await indexPhotos(paths, onProgress: onProgress)
    }

    func removePhoto(_ path: String) async {
        guard globalVar.imageAIEnabled else { return }
        log("FaceIndexer: removal queued for \(path)")
    }
}
