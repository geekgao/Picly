import Foundation

struct SearchResultImage: Codable {
    let id: String
    let path: String
    let width: Int
    let height: Int
    let fileSize: Int
    let modificationDate: String
    let checksum: String
    let indexedAt: String
    let latitude: Double?
    let longitude: Double?
    let captureDate: String?
}

struct SearchResultItem: Codable {
    let image: SearchResultImage
    let score: Double
    let rank: Int
}

struct SearchResponse: Codable {
    let results: [SearchResultItem]
}

struct SearchFilter: Codable {
    var dateFrom: Date?
    var dateTo: Date?
    var latitude: Double?
    var longitude: Double?
    var radiusKm: Double?

    var hasAny: Bool {
        dateFrom != nil || dateTo != nil || latitude != nil || longitude != nil
    }
}

struct IndexJob: Codable {
    let jobId: String
    let folderPath: String
    let totalCount: Int
    let processedCount: Int
    let failedCount: Int
    let status: String
    let startedAt: String?
    let completedAt: String?
    let errorMessage: String?
    let withTags: Bool?
    let taggedCount: Int?
    let tagFailedCount: Int?
}

struct IndexRequest: Codable {
    let path: String
    let maxDepth: Int
    let withTags: Bool?
}

struct StatusResponse: Codable {
    let imageCount: Int
    let indexedCount: Int
    let lastJob: IndexJob?
    let taggerAvailable: Bool?
    let taggerModel: String?
    let faceCount: Int?
    let personCount: Int?
}

struct PreloadResponse: Codable {
    let status: String
}

// MARK: - Tagging

struct TagResult: Codable {
    let tag: String
    let confidence: Float32
}

struct TagResponse: Codable {
    let path: String
    let tags: [TagResult]
    let modelName: String
}

// MARK: - AI Tag Cache

final class AITagCache: @unchecked Sendable {
    static let shared = AITagCache()
    private let lock = NSLock()
    private var pathTags: [String: [TagResult]] = [:]
    private var tagPaths: [String: Set<String>] = [:]
    private var searchCache: [String: [String]] = [:]

    func get(path: String) -> [TagResult]? {
        lock.withLock { pathTags[path] }
    }

    func set(path: String, tags: [TagResult]) {
        lock.withLock {
            if let old = pathTags[path] {
                for oldTag in old {
                    tagPaths[oldTag.tag]?.remove(path)
                    if tagPaths[oldTag.tag]?.isEmpty == true { tagPaths.removeValue(forKey: oldTag.tag) }
                }
            }
            pathTags[path] = tags
            for tagResult in tags {
                tagPaths[tagResult.tag, default: []].insert(path)
            }
        }
    }

    func paths(for tag: String) -> [String] {
        lock.withLock { Array(tagPaths[tag] ?? []) }
    }

    var allPaths: [String] {
        lock.withLock { Array(pathTags.keys) }
    }

    func remove(path: String) {
        lock.withLock {
            if let old = pathTags.removeValue(forKey: path) {
                for oldTag in old {
                    tagPaths[oldTag.tag]?.remove(path)
                    if tagPaths[oldTag.tag]?.isEmpty == true { tagPaths.removeValue(forKey: oldTag.tag) }
                }
            }
        }
    }

    var isEmpty: Bool {
        lock.withLock { pathTags.isEmpty }
    }

    // MARK: - Search result cache

    func getSearchCache(tag: String) -> [String]? {
        lock.withLock { searchCache[tag] }
    }

    func setSearchCache(tag: String, paths: [String]) {
        lock.withLock { searchCache[tag] = paths }
    }

    func invalidateSearchCache() {
        lock.withLock { searchCache.removeAll() }
    }
}
