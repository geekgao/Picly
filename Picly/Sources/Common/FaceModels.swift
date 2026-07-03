import Foundation

struct FaceSearchMatch: Codable {
    let faceId: String
    let photoPath: String
    let score: Float
    let bboxX: Double
    let bboxY: Double
    let bboxW: Double
    let bboxH: Double
}

struct FaceSearchResultsResponse: Codable {
    let results: [FaceSearchMatch]
}

struct PersonInfo: Codable, Identifiable {
    let id: String
    let name: String?
    let coverFaceId: String?
    let coverPhotoPath: String?
    let coverBboxX: Double?
    let coverBboxY: Double?
    let coverBboxW: Double?
    let coverBboxH: Double?
    let faceCount: Int
    let photoCount: Int
    let createdAt: Date
    let updatedAt: Date
}

struct PersonsListResponse: Codable {
    let persons: [PersonInfo]
}

struct PersonPhotosResponse: Codable {
    let photos: [String]
}

struct FaceStatusResponse: Codable {
    let faceCount: Int
    let personCount: Int
}
