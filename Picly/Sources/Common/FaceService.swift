import Foundation

actor FaceService {
    static let shared = FaceService()

    private let session: URLSession
    private let imageAI = ImageAIService.shared
    private let decoder: JSONDecoder

    private var baseURL: URL {
        URL(string: "http://127.0.0.1:8972/api/v1")!
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    private func ensureRunning() async throws {
        try await imageAI.ensureRunning()
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await ensureRunning()
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let (data, response) = try await session.data(for: URLRequest(url: components.url!))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw httpError(response, data: data)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func post(_ path: String, json: [String: Any]) async throws {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw httpError(response, data: data)
        }
    }

    private func put(_ path: String, json: [String: Any]) async throws {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw httpError(response, data: data)
        }
    }

    private func httpError(_ response: URLResponse, data: Data) -> ImageAIError {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data, encoding: .utf8) ?? ""
        return ImageAIError.httpError(code, body: body)
    }

    // MARK: - Public API

    func indexFaces(path: String) async throws {
        try await post("faces/index", json: ["path": path])
    }

    func searchFacesByImage(path: String, topK: Int = 50, minScore: Float = 0) async throws -> [FaceSearchMatch] {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("faces/search-by-image")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "path": path, "topK": topK, "minScore": minScore
        ] as [String: Any])
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw httpError(response, data: data)
        }
        return try decoder.decode(FaceSearchResultsResponse.self, from: data).results
    }

    func searchFacesByFaceId(faceId: String, topK: Int = 50, minScore: Float = 0) async throws -> [FaceSearchMatch] {
        try await get("faces/search", query: [
            "faceId": faceId,
            "topK": "\(topK)",
            "minScore": "\(minScore)"
        ])
    }

    func getPersons() async throws -> [PersonInfo] {
        let resp: PersonsListResponse = try await get("persons")
        return resp.persons
    }

    func getPerson(id: String) async throws -> PersonInfo {
        try await get("persons/\(id)")
    }

    func getPersonPhotos(id: String) async throws -> [String] {
        let resp: PersonPhotosResponse = try await get("persons/\(id)/photos")
        return resp.photos
    }

    func updatePersonName(id: String, name: String?) async throws {
        try await put("persons/\(id)", json: ["name": name as Any])
    }

    func mergePersons(fromId: String, intoId: String) async throws {
        try await post("persons/merge", json: ["fromId": fromId, "intoId": intoId])
    }

    func splitFace(faceId: String) async throws {
        try await post("persons/split", json: ["faceId": faceId])
    }

    func mergeFace(faceId: String, intoPersonId: String) async throws {
        try await post("persons/merge-face", json: ["faceId": faceId, "intoPersonId": intoPersonId])
    }

    func getFaceStatus() async throws -> (faceCount: Int, personCount: Int) {
        let resp: FaceStatusResponse = try await get("faces/status")
        return (resp.faceCount, resp.personCount)
    }
}
