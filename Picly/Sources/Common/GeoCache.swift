import Cocoa

/// Thread-safe in-memory geo index with JSON persistence.
///
/// Indexes files by geohash (precision 7, ~150m) for fast coarse filtering,
/// then refines with Haversine distance. Persisted as JSON in
/// `~/Library/Application Support/Picly/GeoCache.json`.
final class GeoCache {
    static let shared = GeoCache()

    // MARK: - Persisted data

    private struct PersistedData: Codable {
        var version: Int
        var entries: [String: Entry]
    }

    struct Entry: Codable {
        var lat: Double
        var lon: Double
    }

    // MARK: - Private state

    /// geohash7 → [filePath: Entry]
    private var index: [String: [String: Entry]] = [:]
    private let lock = NSLock()
    private let cacheURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Picly", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("GeoCache.json")
        loadFromDisk()
        NotificationCenter.default.addObserver(self, selector: #selector(saveImmediately), name: NSApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveImmediately), name: NSApplication.didResignActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// Add or update a file entry.
    func addFile(path: String, lat: Double, lon: Double) {
        let gh = geohash(lat: lat, lon: lon, precision: 7)
        lock.lock()
        index[gh, default: [:]][path] = Entry(lat: lat, lon: lon)
        lock.unlock()
    }

    /// Remove a file entry.
    func removeFile(path: String, lat: Double? = nil, lon: Double? = nil) {
        lock.lock()
        if let lat, let lon {
            let gh = geohash(lat: lat, lon: lon, precision: 7)
            index[gh]?.removeValue(forKey: path)
            if index[gh]?.isEmpty == true { index.removeValue(forKey: gh) }
        } else {
            for (gh, paths) in index {
                if paths[path] != nil {
                    index[gh]?.removeValue(forKey: path)
                    if index[gh]?.isEmpty == true { index.removeValue(forKey: gh) }
                    break
                }
            }
        }
        lock.unlock()
    }

    /// Search for files within `radiusKm` of `(lat, lon)`.
    /// Does a full scan over all indexed entries — in-memory so trivially fast
    /// even for 100K entries. Geohash index is maintained for fast add/remove
    /// and persistence, but not used during search (prevents coarse-filter misses
    /// when radius is much larger than a geohash cell).
    /// - Returns: Array of (path, distanceKm) sorted by distance ascending.
    func search(lat: Double, lon: Double, radiusKm: Double) -> [(path: String, distanceKm: Double)] {
        lock.lock()
        let snapshot = index.flatMap { $0.value.map { ($0.key, $0.value) } }
        lock.unlock()

        var results: [(path: String, distanceKm: Double)] = []
        for (path, entry) in snapshot {
            let d = haversine(lat1: lat, lon1: lon, lat2: entry.lat, lon2: entry.lon)
            if d <= radiusKm {
                results.append((path, d))
            }
        }
        results.sort { $0.distanceKm < $1.distanceKm }
        return results
    }

    /// Total number of indexed files.
    var count: Int {
        lock.lock()
        let c = index.reduce(0) { $0 + $1.value.count }
        lock.unlock()
        return c
    }

    /// Clear entire index.
    func clearAll() {
        lock.lock()
        index.removeAll()
        lock.unlock()
        saveToDisk([:])
    }

    // MARK: - Persistence

    @objc private func saveImmediately() {
        lock.lock()
        let snapshot = index
        lock.unlock()
        saveToDisk(snapshot)
    }

    private func saveToDisk(_ data: [String: [String: Entry]]) {
        let persisted = PersistedData(version: 1, entries: data.flatMap { gh, entries in
            entries.map { (gh + "|" + $0.key, $0.value) }
        }.reduce(into: [:]) { $0[$1.0] = $1.1 })
        guard let json = try? JSONEncoder().encode(persisted) else { return }
        try? json.write(to: cacheURL, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL),
              let persisted = try? JSONDecoder().decode(PersistedData.self, from: data),
              persisted.version == 1
        else { return }
        lock.lock()
        index.removeAll()
        for (key, entry) in persisted.entries {
            let parts = key.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let gh = String(parts[0])
            let path = String(parts[1])
            index[gh, default: [:]][path] = entry
        }
        lock.unlock()
    }

    // MARK: - Geohash

    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    /// Encode (lat, lon) to a geohash string with given precision.
    private func geohash(lat: Double, lon: Double, precision: Int) -> String {
        var latMin = -90.0, latMax = 90.0
        var lonMin = -180.0, lonMax = 180.0
        var hash = ""
        var isEven = true
        var bit = 0
        var ch = 0

        while hash.count < precision {
            if isEven {
                let mid = (lonMin + lonMax) / 2
                if lon > mid {
                    ch |= (1 << (4 - bit))
                    lonMin = mid
                } else {
                    lonMax = mid
                }
            } else {
                let mid = (latMin + latMax) / 2
                if lat > mid {
                    ch |= (1 << (4 - bit))
                    latMin = mid
                } else {
                    latMax = mid
                }
            }
            isEven.toggle()
            if bit < 4 {
                bit += 1
            } else {
                hash.append(Self.base32[ch])
                bit = 0
                ch = 0
            }
        }
        return hash
    }

    /// Return the geohash itself plus its 8 neighbors.
    private func neighboringGeohashes(_ gh: String, precision: Int) -> Set<String> {
        var result = Set<String>()
        result.insert(gh)
        let dirs: [(lat: Int, lon: Int)] = [
            (0, 1), (0, -1), (1, 0), (-1, 0),
            (1, 1), (1, -1), (-1, 1), (-1, -1)
        ]
        for dir in dirs {
            if let neighbor = shiftGeohash(gh, dLat: dir.lat, dLon: dir.lon, precision: precision) {
                result.insert(neighbor)
            }
        }
        return result
    }

    /// Shift a geohash by dLat/dLon grid steps.
    private func shiftGeohash(_ gh: String, dLat: Int, dLon: Int, precision: Int) -> String? {
        guard gh.count == precision else { return nil }
        var latMin = -90.0, latMax = 90.0
        var lonMin = -180.0, lonMax = 180.0
        var isEven = true
        var latBits: [Bool] = []
        var lonBits: [Bool] = []

        for ch in gh {
            guard let idx = Self.base32.firstIndex(of: ch) else { return nil }
            let v = Self.base32.distance(from: Self.base32.startIndex, to: idx)
            for b in 0..<5 {
                let bit = (v >> (4 - b)) & 1
                if isEven {
                    lonBits.append(bit == 1)
                } else {
                    latBits.append(bit == 1)
                }
                isEven.toggle()
            }
        }

        // Decode intervals
        var latInterval = latMax - latMin
        for b in latBits {
            latInterval /= 2
            if b { latMin += latInterval } else { latMax -= latInterval }
        }
        var lonInterval = lonMax - lonMin
        for b in lonBits {
            lonInterval /= 2
            if b { lonMin += lonInterval } else { lonMax -= lonInterval }
        }

        let latCenter = (latMin + latMax) / 2
        let lonCenter = (lonMin + lonMax) / 2

        let newLat = latCenter + Double(dLat) * latInterval
        let newLon = lonCenter + Double(dLon) * lonInterval

        guard newLat >= -90, newLat <= 90, newLon >= -180, newLon <= 180 else { return nil }
        return geohash(lat: newLat, lon: newLon, precision: precision)
    }

    // MARK: - Haversine

    private func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
