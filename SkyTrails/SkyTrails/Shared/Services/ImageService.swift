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

protocol ImageProviding {
    func image(for key: String) async -> UIImage?
    func prefetch(keys: [String]) async
    func refreshManifestIfNeeded(force: Bool) async
}

@MainActor
final class ImageService: ImageProviding {
    static let shared = ImageService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheTTL: TimeInterval = 24 * 60 * 60
    private let refreshKey = "identification_manifest_last_refresh"
    private let fileManager = FileManager.default
    private let manifestDecoder = JSONDecoder()

    private var manifest: IdentificationManifest?
    private var failedRemoteKeys: Set<String> = []
    private let allowedDefaultProfileKeys: Set<String> = [
        "id_canvas_finch_beak_default",
        "id_canvas_finch_head_default",
        "id_canvas_finch_leg_default",
        "id_canvas_finch_tail_default",
    ]
    private let localOnlyKeys: Set<String> = [
        "id_bird_underparts",
        "id_bird_throat",
        "id_bird_thigh",
        "id_bird_wings",
        "id_bird_neck",
        "id_bird_eye",
        "id_bird_facemask",
        "id_bird_nape",
        "id_bird_tail",
        "id_bird_crown",
        "id_bird_beak",
        "id_bird_chest",
        "id_bird_back",
        "id_bird_leg",
    ]

    private init() {
        memoryCache.countLimit = 500
    }

    func image(for key: String) async -> UIImage? {
        let normalizedKey = normalizeKey(key)
        if normalizedKey.isEmpty { return nil }
        let keyCandidates = keyLookupCandidates(for: normalizedKey)

        let memKey = normalizedKey as NSString
        if let cached = memoryCache.object(forKey: memKey) {
            return cached
        }

        if localOnlyKeys.contains(normalizedKey) {
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }

        if isDisallowedDefaultProfileKey(normalizedKey) {
            return nil
        }

        await refreshManifestIfNeeded(force: false)

        let diskKey = diskCacheKey(for: normalizedKey)
        if let diskImage = loadFromDisk(cacheKey: diskKey) {
            memoryCache.setObject(diskImage, forKey: memKey)
            return diskImage
        }

        if failedRemoteKeys.contains(normalizedKey) {
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }

        guard let itemLookup = lookupManifestItem(for: keyCandidates) else {
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

        guard let remoteURL = remoteURL(for: itemLookup.item.path) else {
            failedRemoteKeys.insert(normalizedKey)
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if let status = (response as? HTTPURLResponse)?.statusCode, status >= 400 {
                    failedRemoteKeys.insert(normalizedKey)
                }
                return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
            }
            guard let image = UIImage(data: data) else {
                failedRemoteKeys.insert(normalizedKey)
                return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
            }
            saveToDisk(data: data, cacheKey: diskKey)
            memoryCache.setObject(image, forKey: memKey)
            failedRemoteKeys.remove(normalizedKey)
            return image
        } catch {
            return fallbackAssetImage(for: keyCandidates, originalKey: normalizedKey)
        }
    }

    func prefetch(keys: [String]) async {
        let uniqueKeys = Array(Set(keys.map(normalizeKey).filter { !$0.isEmpty }))
        for key in uniqueKeys {
            _ = await image(for: key)
        }
    }

    func refreshManifestIfNeeded(force: Bool) async {
        if !force,
           let lastRefresh = UserDefaults.standard.object(forKey: refreshKey) as? Date,
           Date().timeIntervalSince(lastRefresh) < cacheTTL,
           manifest != nil {
            return
        }

        guard let manifestURL = manifestURL() else {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: manifestURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            let decoded = try manifestDecoder.decode(IdentificationManifest.self, from: data)
            manifest = decoded
            failedRemoteKeys.removeAll()
            UserDefaults.standard.set(Date(), forKey: refreshKey)
        } catch {
        }
    }

    private func manifestURL() -> URL? {
        guard let config = try? SupabaseConfig.load() else { return nil }
        let bucket = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_IDENTIFICATION_BUCKET") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let manifestPath = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_IDENTIFICATION_MANIFEST_PATH") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let safeBucket = (bucket?.isEmpty == false) ? bucket! : "identification-assets"
        let safeManifestPath = (manifestPath?.isEmpty == false) ? manifestPath! : "identification_manifest.json"

        return config.projectURL.appendingPathComponent("storage/v1/object/public/\(safeBucket)/\(safeManifestPath)")
    }

    private func remoteURL(for objectPath: String, bucketOverride: String? = nil) -> URL? {
        guard let config = try? SupabaseConfig.load() else { return nil }
        let configuredBucket = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_IDENTIFICATION_BUCKET") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBucket = (bucketOverride?.isEmpty == false)
            ? bucketOverride!
            : ((configuredBucket?.isEmpty == false) ? configuredBucket! : "identification-assets")
        let cleanedPath = objectPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleanedPath.isEmpty else { return nil }

        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/storage/v1/object/public/\(safeBucket)/\(cleanedPath)"
        return components?.url
    }

    private func cacheDirectory() -> URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("IdentificationImageCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func diskCacheKey(for key: String) -> String {
        let fingerprint = manifest?.items[key]?.checksum ?? manifest?.items[key]?.path ?? key
        let payload = "\(key)|\(fingerprint)"
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

    private func keyLookupCandidates(for key: String) -> [String] {
        var candidates: [String] = []

        func add(_ value: String) {
            guard !value.isEmpty, !candidates.contains(value) else { return }
            candidates.append(value)
        }

        add(key)
        add(key.replacingOccurrences(of: "-", with: "_"))
        add(key.replacingOccurrences(of: "_", with: "-"))
        add(key.replacingOccurrences(of: " ", with: "_"))
        add(key.replacingOccurrences(of: " ", with: "-"))

        return candidates
    }

    private func lookupManifestItem(for candidates: [String]) -> (key: String, item: ManifestItem)? {
        guard let items = manifest?.items else { return nil }
        for candidate in candidates {
            if let item = items[candidate] {
                return (candidate, item)
            }
        }
        return nil
    }

    private func fallbackAssetImage(for candidates: [String], originalKey: String) -> UIImage? {
        for candidate in candidates {
            if let image = UIImage(named: candidate) {
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
        return !allowedDefaultProfileKeys.contains(key)
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
        let birdBucket = birdBucketName()
        let fileExtensions = ["png", "jpg", "jpeg", "webp"]

        var objectPaths: [String] = []
        for candidate in keyCandidates {
            let lowered = candidate.lowercased()
            for ext in fileExtensions {
                let directPath = "\(lowered).\(ext)"
                if !objectPaths.contains(directPath) {
                    objectPaths.append(directPath)
                }
                let nestedPath = "bird/\(lowered).\(ext)"
                if !objectPaths.contains(nestedPath) {
                    objectPaths.append(nestedPath)
                }
            }
        }

        for objectPath in objectPaths {
            guard let url = remoteURL(for: objectPath, bucketOverride: birdBucket) else {
                continue
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let image = UIImage(data: data) else {
                    continue
                }
                saveToDisk(data: data, cacheKey: diskKey)
                memoryCache.setObject(image, forKey: normalizedKey as NSString)
                return image
            } catch {
                continue
            }
        }

        return nil
    }
}

typealias IdentificationImageService = ImageService
