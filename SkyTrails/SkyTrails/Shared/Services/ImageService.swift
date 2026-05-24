import CryptoKit
import Foundation
import UIKit

struct ManifestItem: Codable {
    let path: String
    let checksum: String?
    let contentType: String?
}

struct IdentificationManifest: Codable {
    let version: String
    let updatedAt: String
    let items: [String: ManifestItem]
}

private enum IdentificationManifestSource: String {
    case main
    case categories
    case shapes
    case birds

    var refreshKey: String {
        switch self {
        case .main:
            return "identification_manifest_last_refresh"
        case .categories:
            return "identification_categories_manifest_last_refresh"
        case .shapes:
            return "identification_shapes_manifest_last_refresh"
        case .birds:
            return "bird_manifest_last_refresh"
        }
    }
}

protocol ImageProviding {
    func image(for key: String, shapeId: String?) async -> UIImage?
    func prefetch(keys: [String]) async
    func refreshManifestIfNeeded(force: Bool) async
    func saveComposedThumbnail(_ image: UIImage, cacheKey: String)
    func loadComposedThumbnail(cacheKey: String) -> UIImage?
}

@MainActor
final class ImageService: ImageProviding {
    static let shared = ImageService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheTTL: TimeInterval = 24 * 60 * 60
    private let fileManager = FileManager.default
    private let manifestDecoder = JSONDecoder()

    private var manifests: [IdentificationManifestSource: IdentificationManifest] = [:]
    private var manifestTasks: [IdentificationManifestSource: Task<Void, Never>] = [:]
    private var imageTasks: [String: Task<UIImage?, Never>] = [:]
    private var failedRemoteKeys: Set<String> = []
    private let prefetchConcurrencyLimit = 6
    private let allowedDefaultProfileKeys: Set<String> = [
        "id_canvas_finch_beak_default",
        "id_canvas_finch_head_default",
        "id_canvas_finch_leg_default",
        "id_canvas_finch_tail_default",
    ]
    private init() {
        memoryCache.countLimit = 500
    }

    func saveComposedThumbnail(_ image: UIImage, cacheKey: String) {
        guard let data = image.pngData(),
              let file = composedThumbCacheDirectory()?.appendingPathComponent(cacheKey) else { return }
        try? data.write(to: file, options: .atomic)
    }

    func loadComposedThumbnail(cacheKey: String) -> UIImage? {
        guard let file = composedThumbCacheDirectory()?.appendingPathComponent(cacheKey),
              let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }

    private func composedThumbCacheDirectory() -> URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("VariationThumbnails", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func cachedImage(for key: String, shapeId: String? = nil) -> UIImage? {
        var normalizedKey = normalizeKey(key)
        let targetShape = "Passeridae_Fringillidae"
        if normalizedKey.lowercased().contains(targetShape.lowercased()) {
            if let range = normalizedKey.range(of: targetShape, options: .caseInsensitive) {
                normalizedKey.replaceSubrange(range, with: "finch")
            }
        }
        
        if normalizedKey.isEmpty { return nil }
        
        let memKey = normalizedKey as NSString
        if let cached = memoryCache.object(forKey: memKey) {
            return cached
        }
        
        let diskKey = diskCacheKey(for: normalizedKey, source: manifestSource(for: normalizedKey))
        if let diskImage = loadFromDisk(cacheKey: diskKey) {
            memoryCache.setObject(diskImage, forKey: memKey)
            return diskImage
        }
        
        return nil
    }

    func image(for key: String, shapeId: String? = nil) async -> UIImage? {
        let requestKey = imageTaskKey(for: key, shapeId: shapeId)
        if let existingTask = imageTasks[requestKey] {
            return await existingTask.value
        }

        let task = Task { @MainActor in
            await self.loadImage(for: key, shapeId: shapeId)
        }
        imageTasks[requestKey] = task
        let image = await task.value
        imageTasks[requestKey] = nil
        return image
    }

    private func loadImage(for key: String, shapeId: String? = nil) async -> UIImage? {
        if key.hasPrefix("http") {
            if let url = URL(string: key) {
                let memKey = key as NSString
                if let cached = memoryCache.object(forKey: memKey) { return cached }
                do {
                    LoggingService.shared.log(message: "Fetching image from URL: \(key)", context: "ImageService")
                    let (data, response) = try await URLSession.shared.data(from: url)
                    if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                       let image = UIImage(data: data) {
                        memoryCache.setObject(image, forKey: memKey)
                        return image
                    } else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        LoggingService.shared.log(message: "Failed to fetch image from URL: \(key) with status \(status)", context: "ImageService")
                    }
                } catch {
                    LoggingService.shared.log(error: error, context: "ImageService")
                }
            }
            // URL download failed — fall through to key-based lookup
        }
        
        var normalizedKey = normalizeKey(key)

        let targetShape = "Passeridae_Fringillidae"
        if normalizedKey.lowercased().contains(targetShape.lowercased()) {
            if let range = normalizedKey.range(of: targetShape, options: .caseInsensitive) {
                normalizedKey.replaceSubrange(range, with: "finch")
            }
        }
        
        if normalizedKey.isEmpty { return nil }
        
        let manifestLookupKey: String
        if normalizedKey.hasPrefix("id_canvas_finch_") {
            let stripped = String(normalizedKey.dropFirst(16))
            let withoutDefault = stripped.replacingOccurrences(of: "_default", with: "")
            manifestLookupKey = withoutDefault
        } else if normalizedKey.hasPrefix("id_canvas_") {
            let stripped = String(normalizedKey.dropFirst(8))
            manifestLookupKey = stripped
        } else if normalizedKey.hasPrefix("canvas_") {
            manifestLookupKey = String(normalizedKey.dropFirst("canvas_".count))
        } else {
            manifestLookupKey = normalizedKey
        }
        
        let keyCandidates = keyLookupCandidates(for: normalizedKey)
        var manifestKeyCandidates = keyLookupCandidates(for: manifestLookupKey)
        manifestKeyCandidates.append(contentsOf: keyLookupCandidates(for: normalizedKey))
        
        var mappedShapeId = shapeId.map { normalizeKey($0) }
        if mappedShapeId == "Passeridae_Fringillidae" {
            mappedShapeId = "finch"
        }
        let normalizedShapeId = mappedShapeId
        let manifestSource = shouldTryBirdBucketFallback(for: normalizedKey)
            ? .birds
            : manifestSource(for: normalizedKey)

        let memKey = normalizedKey as NSString
        if let cached = memoryCache.object(forKey: memKey) {
            return cached
        }

        if isDisallowedDefaultProfileKey(normalizedKey) {
            return nil
        }

        await refreshManifestIfNeeded(force: false, source: manifestSource)

        let diskKey = diskCacheKey(for: normalizedKey, source: manifestSource)
        if let diskImage = loadFromDisk(cacheKey: diskKey) {
            memoryCache.setObject(diskImage, forKey: memKey)
            return diskImage
        }

        if failedRemoteKeys.contains(normalizedKey) {
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }

        guard let itemLookup = lookupManifestItem(for: manifestKeyCandidates, source: manifestSource) else {
            if shouldTryBirdBucketFallback(for: normalizedKey),
               let birdImage = await loadFromBirdBucket(
                   keyCandidates: keyCandidates,
                   normalizedKey: normalizedKey,
                   diskKey: diskKey
               ) {
                return birdImage
            }
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }
        
        guard let remoteURL = remoteURL(
            for: itemLookup.item.path,
            source: manifestSource,
            shapeId: normalizedShapeId
        ) else {
            failedRemoteKeys.insert(normalizedKey)
            if shouldTryBirdBucketFallback(for: normalizedKey),
               let birdImage = await loadFromBirdBucket(
                   keyCandidates: keyCandidates,
                   normalizedKey: normalizedKey,
                   diskKey: diskKey
               ) {
                return birdImage
            }
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }

        do {
            let config = try SupabaseConfig.load()
            var request = URLRequest(url: remoteURL)
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

            LoggingService.shared.log(message: "Fetching manifest image: \(remoteURL.absoluteString)", context: "ImageService")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                LoggingService.shared.log(message: "Manifest image fetch failed with status \(status): \(remoteURL.absoluteString)", context: "ImageService")
                if status >= 400 {
                    failedRemoteKeys.insert(normalizedKey)
                }
                if shouldTryBirdBucketFallback(for: normalizedKey),
                   let birdImage = await loadFromBirdBucket(
                       keyCandidates: keyCandidates,
                       normalizedKey: normalizedKey,
                       diskKey: diskKey
                   ) {
                    return birdImage
                }
                return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
            }
            guard let image = UIImage(data: data) else {
                LoggingService.shared.log(message: "Failed to decode manifest image data: \(remoteURL.absoluteString)", context: "ImageService")
                failedRemoteKeys.insert(normalizedKey)
                if shouldTryBirdBucketFallback(for: normalizedKey),
                   let birdImage = await loadFromBirdBucket(
                       keyCandidates: keyCandidates,
                       normalizedKey: normalizedKey,
                       diskKey: diskKey
                   ) {
                    return birdImage
                }
                return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
            }
            saveToDisk(data: data, cacheKey: diskKey)
            memoryCache.setObject(image, forKey: memKey)
            failedRemoteKeys.remove(normalizedKey)
            return image
        } catch {
            LoggingService.shared.log(error: error, context: "ImageService")
            if shouldTryBirdBucketFallback(for: normalizedKey),
               let birdImage = await loadFromBirdBucket(
                   keyCandidates: keyCandidates,
                   normalizedKey: normalizedKey,
                   diskKey: diskKey
               ) {
                return birdImage
            }
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }
    }

    func prefetch(keys: [String]) async {
        let uniqueKeys = Array(Set(keys.map(normalizeKey).filter { !$0.isEmpty }))
        guard !uniqueKeys.isEmpty else { return }

        var iterator = uniqueKeys.makeIterator()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<min(prefetchConcurrencyLimit, uniqueKeys.count) {
                guard let key = iterator.next() else { break }
                group.addTask {
                    _ = await self.image(for: key, shapeId: nil)
                }
            }

            while await group.next() != nil {
                guard let key = iterator.next() else { continue }
                group.addTask {
                    _ = await self.image(for: key, shapeId: nil)
                }
            }
        }
    }

    func refreshManifestIfNeeded(force: Bool) async {
        await refreshManifestIfNeeded(force: force, source: .main)
        await refreshManifestIfNeeded(force: force, source: .categories)
        await refreshManifestIfNeeded(force: force, source: .shapes)
        await refreshManifestIfNeeded(force: force, source: .birds)
    }

    private func refreshManifestIfNeeded(force: Bool, source: IdentificationManifestSource) async {
        if !force,
           let lastRefresh = UserDefaults.standard.object(forKey: source.refreshKey) as? Date,
           Date().timeIntervalSince(lastRefresh) < cacheTTL,
           manifests[source] != nil {
            return
        }

        // Check if there is already a refresh task in progress for this source
        if let existingTask = manifestTasks[source] {
            await existingTask.value
            return
        }

        // Create a new refresh task and store it
        let newTask = Task {
            guard let manifestURL = manifestURL(for: source) else {
                return
            }

            do {
                let config = try SupabaseConfig.load()
                var request = URLRequest(url: manifestURL)
                request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

                LoggingService.shared.log(message: "Refreshing manifest: \(manifestURL.absoluteString)", context: "ImageService")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    LoggingService.shared.log(message: "Manifest refresh failed with status \(status): \(manifestURL.absoluteString)", context: "ImageService")
                    return
                }
                let decoded = try manifestDecoder.decode(IdentificationManifest.self, from: data)
                manifests[source] = decoded
                failedRemoteKeys.removeAll()
                UserDefaults.standard.set(Date(), forKey: source.refreshKey)
            } catch {
                LoggingService.shared.log(error: error, context: "ImageService")
            }
        }

        manifestTasks[source] = newTask
        await newTask.value
        manifestTasks[source] = nil
    }

    private func manifestURL(for source: IdentificationManifestSource) -> URL? {
        guard let config = try? SupabaseConfig.load() else { return nil }
        let bucketKey: String
        let manifestPathKey: String
        let fallbackBucket: String
        let fallbackPath: String
        switch source {
        case .main:
            bucketKey = "SUPABASE_IDENTIFICATION_BUCKET"
            manifestPathKey = "SUPABASE_IDENTIFICATION_MANIFEST_PATH"
            fallbackBucket = "identification-assets"
            fallbackPath = "identification_manifest.json"
        case .categories:
            bucketKey = "SUPABASE_IDENTIFICATION_BUCKET"
            manifestPathKey = "SUPABASE_IDENTIFICATION_CATEGORY_MANIFEST_PATH"
            fallbackBucket = "identification-assets"
            fallbackPath = "identification_categories_manifest.json"
        case .shapes:
            bucketKey = "SUPABASE_IDENTIFICATION_SHAPES_BUCKET"
            manifestPathKey = "SUPABASE_IDENTIFICATION_SHAPES_MANIFEST_PATH"
            fallbackBucket = "identification-shapes"
            fallbackPath = "identification_shapes_manifest.json"
        case .birds:
            bucketKey = "SUPABASE_BIRD_BUCKET"
            manifestPathKey = "SUPABASE_BIRD_MANIFEST_PATH"
            fallbackBucket = "bird"
            fallbackPath = "bird_manifest.json"
        }
        let bucket = (Bundle.main.object(forInfoDictionaryKey: bucketKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let manifestPath = (Bundle.main.object(forInfoDictionaryKey: manifestPathKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let safeBucket = (bucket?.isEmpty == false) ? bucket! : fallbackBucket
        let safeManifestPath = (manifestPath?.isEmpty == false) ? manifestPath! : fallbackPath

        return config.projectURL
            .appendingPathComponent("storage/v1/object/public")
            .appendingPathComponent(safeBucket)
            .appendingPathComponent(safeManifestPath)
    }

    private func remoteURL(
        for objectPath: String,
        source: IdentificationManifestSource = .main,
        bucketOverride: String? = nil,
        shapeId: String? = nil
    ) -> URL? {
        guard let config = try? SupabaseConfig.load() else { return nil }
        let configuredBucketKey: String
        let fallbackBucket: String
        switch source {
        case .main, .categories:
            configuredBucketKey = "SUPABASE_IDENTIFICATION_BUCKET"
            fallbackBucket = "identification-assets"
        case .shapes:
            configuredBucketKey = "SUPABASE_IDENTIFICATION_SHAPES_BUCKET"
            fallbackBucket = "identification-shapes"
        case .birds:
            configuredBucketKey = "SUPABASE_BIRD_BUCKET"
            fallbackBucket = "bird"
        }
        let configuredBucket = (Bundle.main.object(forInfoDictionaryKey: configuredBucketKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBucket = (bucketOverride?.isEmpty == false)
            ? bucketOverride!
            : ((configuredBucket?.isEmpty == false) ? configuredBucket! : fallbackBucket)
        
        var cleanedPath = objectPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleanedPath.isEmpty else { return nil }

        if source == .main, let shapeId = shapeId, !shapeId.isEmpty {
            let shapePrefix = "canvas/\(shapeId)/"
            if !cleanedPath.hasPrefix(shapePrefix) {
                cleanedPath = shapePrefix + cleanedPath
            }
        }

        return config.projectURL
            .appendingPathComponent("storage/v1/object/public")
            .appendingPathComponent(safeBucket)
            .appendingPathComponent(cleanedPath)
    }

    private func cacheDirectory() -> URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("IdentificationImageCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func diskCacheKey(for key: String, source: IdentificationManifestSource) -> String {
        let manifest = manifests[source]
        let fingerprint = manifest?.items[key]?.checksum ?? manifest?.items[key]?.path ?? key
        let payload = "\(source.rawValue)|\(key)|\(fingerprint)"
        let hash = SHA256.hash(data: Data(payload.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func loadFromDisk(cacheKey: String) -> UIImage? {
        guard let file = cacheDirectory()?.appendingPathComponent(cacheKey) else { return nil }
        guard let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(data: Data, cacheKey: String) {
        guard let file = cacheDirectory()?.appendingPathComponent(cacheKey) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private func normalizeKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func imageTaskKey(for key: String, shapeId: String?) -> String {
        "\(normalizeKey(key))|\(shapeId.map { normalizeKey($0) } ?? "")"
    }

    private func keyLookupCandidates(for key: String) -> [String] {
        var candidates: [String] = []

        func add(_ value: String) {
            guard !value.isEmpty, !candidates.contains(value) else { return }
            candidates.append(value)
        }

        // 1. Original
        add(key)
        
        // 2. Cleaned (no apostrophes)
        let cleaned = key.replacingOccurrences(of: "'", with: "")
        add(cleaned)

        // 3. Various separators
        let separators = ["-", "_", " "]
        for s in separators {
            add(cleaned.replacingOccurrences(of: " ", with: s))
            add(cleaned.replacingOccurrences(of: "-", with: s))
            add(cleaned.replacingOccurrences(of: "_", with: s))
        }

        return candidates
    }

    private func lookupManifestItem(
        for candidates: [String],
        source: IdentificationManifestSource
    ) -> (key: String, item: ManifestItem)? {
        guard let items = manifests[source]?.items else { return nil }
        for candidate in candidates {
            // Check original and lowercased in manifest
            if let item = items[candidate] {
                return (candidate, item)
            }
            if let item = items[candidate.lowercased()] {
                return (candidate, item)
            }
        }
        return nil
    }

    private func manifestSource(for key: String) -> IdentificationManifestSource {
        if key.hasPrefix("id_bird_") {
            return .categories
        }
        if key.hasPrefix("id_shape_"),
           !key.contains("_base") {
            return .shapes
        }
        return .main
    }

    private func fallbackAssetImage(for candidates: [String], originalKey: String) -> UIImage? {
        for candidate in candidates {
            if let image = UIImage(named: candidate) {
                memoryCache.setObject(image, forKey: originalKey as NSString)
                return image
            }
            if let image = UIImage(named: candidate.lowercased()) {
                memoryCache.setObject(image, forKey: originalKey as NSString)
                return image
            }
        }
        return nil
    }

    private func isDisallowedDefaultProfileKey(_ key: String) -> Bool {
        guard key.hasPrefix("id_canvas_"), key.hasSuffix("_default") else {
            return false
        }
        // Keep finch guardrails, but allow default profile keys for other shapes.
        if key.hasPrefix("id_canvas_finch_") {
            return !allowedDefaultProfileKeys.contains(key)
        }
        return false
    }

    private func shouldTryBirdBucketFallback(for key: String) -> Bool {
        guard !key.hasPrefix("id_"), !key.hasPrefix("canvas_"), !key.hasPrefix("shape_") else {
            return false
        }
        return true
    }

    private func birdBucketName() -> String {
        let bucket = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_BIRD_BUCKET") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (bucket?.isEmpty == false) ? bucket! : "bird"
    }

    private func loadFromBirdBucket(
        keyCandidates: [String],
        normalizedKey: String,
        diskKey: String
    ) async -> UIImage? {
        await refreshManifestIfNeeded(force: false, source: .birds)

        let birdDiskKey = diskCacheKey(for: normalizedKey, source: .birds)
        if let diskImage = loadFromDisk(cacheKey: birdDiskKey) {
            memoryCache.setObject(diskImage, forKey: normalizedKey as NSString)
            return diskImage
        }

        if let manifestImage = await loadFromBirdManifest(
            keyCandidates: keyCandidates,
            normalizedKey: normalizedKey,
            diskKey: birdDiskKey
        ) {
            return manifestImage
        }

        let birdBucket = birdBucketName()
        let fileExtensions = ["png", "jpg", "jpeg", "webp"]
        let folderPrefixes = ["", "bird/", "birds/"]

        var objectPaths: [String] = []
        for candidate in keyCandidates {
            // Try both original case and lowercased
            let variations = [candidate, candidate.lowercased()]
            
            for variation in variations {
                // 1. Try exactly as variation (handles "bird.jpg" cases)
                if !objectPaths.contains(variation) {
                    objectPaths.append(variation)
                }
                
                // 2. Try with extensions and folders
                for ext in fileExtensions {
                    let filename = "\(variation).\(ext)"
                    for prefix in folderPrefixes {
                        let fullPath = "\(prefix)\(filename)"
                        if !objectPaths.contains(fullPath) {
                            objectPaths.append(fullPath)
                        }
                    }
                }
            }
        }

        for objectPath in objectPaths {
            guard let url = remoteURL(for: objectPath, bucketOverride: birdBucket) else {
                continue
            }
            do {
                let config = try SupabaseConfig.load()
                var request = URLRequest(url: url)
                request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

                LoggingService.shared.log(message: "Fetching bird bucket image: \(url.absoluteString)", context: "ImageService")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let image = UIImage(data: data) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    LoggingService.shared.log(message: "Bird bucket image fetch failed with status \(status): \(url.absoluteString)", context: "ImageService")
                    continue
                }
                saveToDisk(data: data, cacheKey: diskKey)
                saveToDisk(data: data, cacheKey: birdDiskKey)
                memoryCache.setObject(image, forKey: normalizedKey as NSString)
                return image
            } catch {
                LoggingService.shared.log(error: error, context: "ImageService")
                continue
            }
        }

        return nil
    }

    private func loadFromBirdManifest(
        keyCandidates: [String],
        normalizedKey: String,
        diskKey: String
    ) async -> UIImage? {
        guard let itemLookup = lookupManifestItem(for: keyCandidates, source: .birds),
              let url = remoteURL(for: itemLookup.item.path, source: .birds) else {
            return nil
        }

        do {
            let config = try SupabaseConfig.load()
            var request = URLRequest(url: url)
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

            LoggingService.shared.log(message: "Fetching bird manifest image: \(url.absoluteString)", context: "ImageService")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                LoggingService.shared.log(message: "Bird manifest image fetch failed with status \(status): \(url.absoluteString)", context: "ImageService")
                return nil
            }

            saveToDisk(data: data, cacheKey: diskKey)
            memoryCache.setObject(image, forKey: normalizedKey as NSString)
            failedRemoteKeys.remove(normalizedKey)
            return image
        } catch {
            LoggingService.shared.log(error: error, context: "ImageService")
            return nil
        }
    }
}

typealias IdentificationImageService = ImageService
