import Foundation

actor ImageAIService {
    static let shared = ImageAIService()

    private var process: Process?
    private var monitorTask: Task<Void, Never>?
    private let port: UInt16 = 8972
    private let session: URLSession
    private var isStartInProgress = false

    private var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)/api/v1")!
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        session = URLSession(configuration: config)
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    private func watchedDirectories() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Pictures",
            "\(home)/Downloads",
            "\(home)/Desktop",
            "\(home)/Documents"
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }

    func startWatching() {
        guard globalVar.imageAIEnabled else { return }
        Task { await DirectoryWatcher.shared.start(watching: watchedDirectories()) }
    }

    func stopWatching() {
        Task { await DirectoryWatcher.shared.stop() }
    }

    func startIfEnabled() {
        guard globalVar.imageAIEnabled else { return }
        start()
    }

    func start() {
        guard process == nil || !process!.isRunning else { return }
        guard !isStartInProgress else { return }
        isStartInProgress = true
        process?.terminate()
        process = nil
        monitorTask?.cancel()
        startWatching()

        let dataDir: String = {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let existingDir = "\(home)/.imageai/data"
            if FileManager.default.fileExists(atPath: existingDir) {
                return existingDir
            }
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Picly/ImageAI", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.path
        }()

        let binaryPath: String
        if let bundlePath = Bundle.main.path(forResource: "imageai", ofType: nil, inDirectory: nil) {
            binaryPath = bundlePath
        } else {
            binaryPath = "/Users/lisheng/Workdir/imageai/.build/out/Products/Release/imageai"
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["serve", "--port", "\(port)", "--data-dir", dataDir]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        proc.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.scheduleRestartIfNeeded()
            }
        }

        do {
            try proc.run()
            process = proc
            isStartInProgress = false
            log("ImageAI server started on port \(port) (binary: \(binaryPath))")

            monitorTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self = self else { return }
                do {
                    _ = try await self.status()
                    log("ImageAI server is ready")
                } catch {
                    log("ImageAI server not ready after 3s: \(error.localizedDescription)")
                }
            }
        } catch {
            isStartInProgress = false
            log("Failed to start ImageAI server: \(error.localizedDescription)")
        }
    }

    func stop() {
        stopWatching()
        monitorTask?.cancel()
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        // Also kill any external server on the same port
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "imageai serve.*--port \(port)"]
        try? task.run()
        task.waitUntilExit()
        log("ImageAI server stopped")
    }

    private func scheduleRestartIfNeeded() {
        guard globalVar.imageAIEnabled else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self?.start()
        }
    }

    private func pollServerReady() async -> Bool {
        let url = baseURL.appendingPathComponent("status")
        for _ in 0..<120 {
            do {
                let (_, resp) = try await session.data(for: URLRequest(url: url))
                if (resp as? HTTPURLResponse)?.statusCode == 200 { return true }
            } catch {}
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    func ensureRunning() async throws {
        if isRunning, await pollServerReady() { return }
        // Check if an external server is already listening on the port
        if await pollServerReady() { return }
        start()
        for _ in 0..<120 {
            if isRunning, await pollServerReady() {
                log("ImageAI server and models ready")
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        log("ImageAI server failed to become ready within 60s")
        throw ImageAIError.notRunning
    }

    // MARK: - API calls

    func search(query: String, topK: Int = 200, minScore: Float = 0.15, filter: SearchFilter? = nil) async throws -> [SearchResultItem] {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("search")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "topK", value: "\(topK)"),
            URLQueryItem(name: "minScore", value: "\(minScore)")
        ]
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let filter = filter {
            if let dateFrom = filter.dateFrom {
                items.append(URLQueryItem(name: "dateFrom", value: isoFormatter.string(from: dateFrom)))
            }
            if let dateTo = filter.dateTo {
                items.append(URLQueryItem(name: "dateTo", value: isoFormatter.string(from: dateTo)))
            }
            if let lat = filter.latitude {
                items.append(URLQueryItem(name: "lat", value: "\(lat)"))
            }
            if let lng = filter.longitude {
                items.append(URLQueryItem(name: "lng", value: "\(lng)"))
            }
            if let radius = filter.radiusKm {
                items.append(URLQueryItem(name: "radiusKm", value: "\(radius)"))
            }
        }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError(code, body: body)
        }
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results
    }

    func index(path: String, maxDepth: Int = 3) async throws -> IndexJob {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("index")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let reqBody = IndexRequest(path: path, maxDepth: maxDepth)
        request.httpBody = try JSONEncoder().encode(reqBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 202 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, body: body)
        }
        return try JSONDecoder().decode(IndexJob.self, from: data)
    }

    func status() async throws -> StatusResponse {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("status")
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, body: body)
        }
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }

    func searchByImage(path: String, topK: Int = 200, minScore: Float = 0.35, filter: SearchFilter? = nil) async throws -> [SearchResultItem] {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("search-by-image")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "path": path,
            "topK": topK
        ]
        if minScore > 0 {
            body["minScore"] = minScore
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError(code, body: body)
        }
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results
    }

    func indexFile(path: String) async throws {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("index-file")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["path": path]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError(code, body: body)
        }
    }

    func searchByColor(colors: [(r: Double, g: Double, b: Double)], tolerance: Double = 0.15, topK: Int = 200) async throws -> [SearchResultItem] {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("search-by-color")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let colorsStr = colors.map { String(format: "%.3f,%.3f,%.3f", $0.r, $0.g, $0.b) }.joined(separator: "|")
        components.queryItems = [
            URLQueryItem(name: "colors", value: colorsStr),
            URLQueryItem(name: "tolerance", value: "\(tolerance)"),
            URLQueryItem(name: "topK", value: "\(topK)")
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError(code, body: body)
        }
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results
    }

    func deleteImage(path: String) async throws {
        try await ensureRunning()
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let url = baseURL.appendingPathComponent("images?path=\(encoded)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError(code, body: body)
        }
    }

    func preload() async throws {
        try await ensureRunning()
        let url = baseURL.appendingPathComponent("preload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, body: body)
        }
    }
}

enum ImageAIError: LocalizedError {
    case invalidQuery
    case httpError(Int, body: String)
    case notRunning

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .httpError(let code, let body):
            if !body.isEmpty { return "服务器返回错误 \(code): \(body)" }
            return "服务器返回错误 \(code)"
        case .notRunning:
            return "无法连接服务器"
        }
    }
}
