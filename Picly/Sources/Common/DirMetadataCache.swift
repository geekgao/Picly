//
//  DirMetadataCache.swift
//  Picly
//

import Foundation
import Cocoa

/// 目录元数据缓存，避免重复读取不变文件的属性。
///
/// 对每个目录缓存文件名集合（不读 fileSize/modDate），
/// 当目录重新打开时，快速对比当前文件名列表与缓存：
/// - 完全一致 → 跳过整个扫描（BTree 和视图不受影响）
/// - 有变化 → 执行完整扫描，结束后更新缓存
///
/// 文件在 exFAT/NAS 等慢速存储上效果显著。
class DirMetadataCache {

    static let shared = DirMetadataCache()

    // MARK: - Persisted data structures

    private struct PersistedData: Codable {
        var version: Int
        var folders: [String: FolderEntry]
    }

    struct FileInfo: Codable {
        var fileSize: Int
        var modDate: Date
        var imageW: CGFloat
        var imageH: CGFloat
        var isGetImageSizeFail: Bool
        var gpsLat: Double?
        var gpsLon: Double?
    }

    struct FolderEntry: Codable {
        var fileNames: [String]
        var isShowHiddenFile: Bool
        var fileInfos: [String: FileInfo] = [:]
        var lastChecked: Date = Date()
    }

    // MARK: - Private state

    private var cache: [String: FolderEntry] = [:]
    private let lock = NSLock()
    private let cacheFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Picly", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheFileURL = dir.appendingPathComponent("DirMetadataCache.json")
        loadFromDisk()
        NotificationCenter.default.addObserver(self, selector: #selector(saveImmediately), name: NSApplication.willTerminateNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func saveImmediately() {
        lock.lock()
        let snapshot = cache
        lock.unlock()
        saveToDisk(snapshot)
    }

    // MARK: - Public API

    /// 检查目录内容是否未发生变化。
    ///
    /// 仅读取当前目录的文件名列表（不请求任何属性），
    /// 与缓存的文件名集合对比。一致则返回 `true`。
    func isDirectoryUnchanged(_ folderURL: URL, isShowHiddenFile: Bool) -> Bool {
        let key = folderURL.absoluteString
        lock.lock()
        let cached = cache[key]
        lock.unlock()

        guard let cached else { return false }
        if cached.isShowHiddenFile != isShowHiddenFile { return false }
        // 外置卷 TTL 放宽到 120 秒（用户不会频繁修改外置卷内容），
        // 内置卷保持 5 秒以确保文件新增及时可见。
        let ttl: TimeInterval = VolumeManager.shared.isExternalVolume(folderURL) ? 120 : 5
        if Date().timeIntervalSince(cached.lastChecked) > ttl { return false }

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return false }

        var currentNames: Set<String> = []
        currentNames.reserveCapacity(urls.count)
        for url in urls {
            let name = url.lastPathComponent
            if name.hasPrefix("._") || name == ".DS_Store" { continue }
            currentNames.insert(name)
        }

        let cachedNames = Set(cached.fileNames)
        return currentNames == cachedNames
    }

    /// 更新目录快照（应在完整扫描后调用）。
    /// 同步写入磁盘，确保进程终止时缓存不丢失。
    func updateSnapshot(_ folderURL: URL, fileNames: [String], isShowHiddenFile: Bool) {
        let key = folderURL.absoluteString
        lock.lock()
        let oldEntry = cache[key]
        var entry = FolderEntry(fileNames: fileNames, isShowHiddenFile: isShowHiddenFile, lastChecked: Date())
        if let old = oldEntry {
            entry.fileInfos = old.fileInfos
        }
        cache[key] = entry
        let snapshot = cache
        lock.unlock()
        saveToDisk(snapshot)
    }

    /// 获取缓存的图像尺寸
    func getImageInfo(for filePath: String, modDate: Date, in folderURL: URL) -> FileInfo? {
        let folderKey = folderURL.absoluteString
        lock.lock()
        let entry = cache[folderKey]
        lock.unlock()
        return entry?.fileInfos["\(filePath)|\(modDate.timeIntervalSince1970)"]
    }

    /// 保存图像尺寸到缓存
    func setImageInfo(_ info: FileInfo, for filePath: String, modDate: Date, in folderURL: URL) {
        let folderKey = folderURL.absoluteString
        let infoKey = "\(filePath)|\(modDate.timeIntervalSince1970)"
        lock.lock()
        if cache[folderKey] != nil {
            cache[folderKey]!.fileInfos[infoKey] = info
        }
        lock.unlock()
    }

    /// 获取目录的快照
    func getSnapshot(_ folderURL: URL) -> FolderEntry? {
        let key = folderURL.absoluteString
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    /// 清除所有缓存
    func clearAll() {
        lock.lock()
        cache.removeAll()
        let snapshot = cache
        lock.unlock()
        saveToDisk(snapshot)
    }

    /// 清除指定目录的缓存（触发下次完整扫描）
    func removeCache(for folderURL: URL) {
        let key = folderURL.absoluteString
        lock.lock()
        cache.removeValue(forKey: key)
        let snapshot = cache
        lock.unlock()
        saveToDisk(snapshot)
    }

    // MARK: - Persistence

    private func saveToDisk(_ data: [String: FolderEntry]) {
        do {
            let persisted = PersistedData(version: 1, folders: data)
            let jsonData = try JSONEncoder().encode(persisted)
            try jsonData.write(to: cacheFileURL, options: .atomic)
        } catch {
            log("DirMetadataCache save failed: \(error)", level: .error)
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let persisted = try JSONDecoder().decode(PersistedData.self, from: data)
            lock.lock()
            cache = persisted.folders
            lock.unlock()
            log("DirMetadataCache: loaded \(persisted.folders.count) folder snapshots", level: .info)
        } catch {
            log("DirMetadataCache load failed: \(error), starting fresh", level: .warn)
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
    }
}
