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
}

struct IndexRequest: Codable {
    let path: String
    let maxDepth: Int
}

struct StatusResponse: Codable {
    let imageCount: Int
    let indexedCount: Int
    let lastJob: IndexJob?
}

struct PreloadResponse: Codable {
    let status: String
}
