
import Foundation
import SwiftData
import UIKit

@MainActor
final class WatchlistPhotoService {
    
    private let context: ModelContext
    private let persistence: WatchlistPersistenceService
    private let fileManager = FileManager.default
    
    init(context: ModelContext, persistence: WatchlistPersistenceService) {
        self.context = context
        self.persistence = persistence
    }
    func attachPhoto(
        to entryID: UUID,
        image: UIImage,
        capturedAt: Date? = nil
    ) throws -> ObservedBirdPhoto {
        guard let entry = try persistence.fetchEntry(id: entryID) else {
            throw WatchlistError.entryNotFound(entryID)
        }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try saveImageToDisk(image: image, filename: filename)
        } catch {
            throw WatchlistError.photoAttachmentFailed(underlying: error)
        }
        let photo = ObservedBirdPhoto(watchlistEntry: entry, imagePath: filename)
        photo.captured_at = capturedAt
        
        context.insert(photo)
        
        do {
            try context.save()
            let photoId = photo.id
            let payloadData = buildPhotoPayloadData(photo, for: .create)
            let localUpdatedAt = photo.uploaded_at
            Task {
                await BackgroundSyncAgent.shared.queuePhoto(
                    id: photoId,
                    payloadData: payloadData,
                    localUpdatedAt: localUpdatedAt,
                    operation: .create
                )
            }
        } catch {
            do {
                try deleteImageFromDisk(filename: filename)
            } catch {
                WatchlistLog.warn("Failed to delete photo file after upload failure: \(filename)")
            }
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        return photo
    }
    func attachExistingPhoto(
        to entryID: UUID,
        imagePath: String,
        capturedAt: Date? = nil
    ) throws -> ObservedBirdPhoto {
        guard let entry = try persistence.fetchEntry(id: entryID) else {
            throw WatchlistError.entryNotFound(entryID)
        }
        guard photoExists(filename: imagePath) else {
            throw WatchlistError.photoAttachmentFailed(
                underlying: NSError(domain: "WatchlistPhotoService", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Photo file not found: \(imagePath)"
                ])
            )
        }
        
        let photo = ObservedBirdPhoto(watchlistEntry: entry, imagePath: imagePath)
        photo.captured_at = capturedAt
        
        context.insert(photo)
        
        do {
            try context.save()
            let photoId = photo.id
            let payloadData = buildPhotoPayloadData(photo, for: .create)
            let localUpdatedAt = photo.uploaded_at
            Task {
                await BackgroundSyncAgent.shared.queuePhoto(
                    id: photoId,
                    payloadData: payloadData,
                    localUpdatedAt: localUpdatedAt,
                    operation: .create
                )
            }
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        return photo
    }
    
    func deletePhoto(id: UUID) throws {
        let descriptor = FetchDescriptor<ObservedBirdPhoto>(
            predicate: #Predicate { $0.id == id }
        )
        
        guard let photo = try context.fetch(descriptor).first else {
            throw WatchlistError.photoAttachmentFailed(
                underlying: NSError(domain: "WatchlistPhotoService", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Photo not found: \(id)"
                ])
            )
        }
        
        let imagePath = photo.imagePath
        let photoId = photo.id
        let photoPayloadData = buildPhotoPayloadData(photo, for: .delete)
        let photoUpdatedAt = photo.uploaded_at
        
        Task {
            await BackgroundSyncAgent.shared.queuePhoto(
                id: photoId,
                payloadData: photoPayloadData,
                localUpdatedAt: photoUpdatedAt,
                operation: .delete
            )
        }
        context.delete(photo)
        
        do {
            try context.save()
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        do {
            try deleteImageFromDisk(filename: imagePath)
        } catch {
            WatchlistLog.warn("Failed to delete photo file: \(imagePath)")
        }
    }
    
    func deleteAllPhotos(for entryID: UUID) throws {
        guard let entry = try persistence.fetchEntry(id: entryID) else {
            throw WatchlistError.entryNotFound(entryID)
        }
        
        let photos = entry.photos ?? []
        let imagePaths = photos.map { $0.imagePath }
        let photoSyncItems = photos.map { photo -> (id: UUID, payloadData: Data?, localUpdatedAt: Date?) in
            (photo.id, buildPhotoPayloadData(photo, for: .delete), photo.uploaded_at)
        }
        
        Task {
            for item in photoSyncItems {
                await BackgroundSyncAgent.shared.queuePhoto(
                    id: item.id,
                    payloadData: item.payloadData,
                    localUpdatedAt: item.localUpdatedAt,
                    operation: .delete
                )
            }
        }
        for photo in photos {
            context.delete(photo)
        }
        
        do {
            try context.save()
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        for imagePath in imagePaths {
            do {
                try deleteImageFromDisk(filename: imagePath)
            } catch {
                WatchlistLog.warn("Failed to delete photo file: \(imagePath)")
            }
        }
    }
    
    func loadImage(filename: String) -> UIImage? {
        guard let url = photoDirectoryURL()?.appendingPathComponent(filename) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    func getPhotos(for entryID: UUID) throws -> [ObservedBirdPhoto] {
        guard let entry = try persistence.fetchEntry(id: entryID) else {
            throw WatchlistError.entryNotFound(entryID)
        }
        
        return entry.photos ?? []
    }
    
    private func saveImageToDisk(image: UIImage, filename: String) throws {
        guard let directory = photoDirectoryURL() else {
            throw NSError(domain: "WatchlistPhotoService", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Could not access photo directory"
            ])
        }
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "WatchlistPhotoService", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Could not convert image to JPEG"
            ])
        }
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL)
    }
    
    private func deleteImageFromDisk(filename: String) throws {
        guard let directory = photoDirectoryURL() else {
            throw NSError(domain: "WatchlistPhotoService", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Could not access photo directory"
            ])
        }
        
        let fileURL = directory.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    private func photoExists(filename: String) -> Bool {
        guard let directory = photoDirectoryURL() else { return false }
        let fileURL = directory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    private func photoDirectoryURL() -> URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("ObservedBirdPhotos", isDirectory: true)
    }
    func cleanupOrphanedPhotos() throws {
        guard let directory = photoDirectoryURL() else { return }
        let filesOnDisk = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let filenames = Set(filesOnDisk.map { $0.lastPathComponent })
        let descriptor = FetchDescriptor<ObservedBirdPhoto>()
        let photos = try context.fetch(descriptor)
        let referencedFilenames = Set(photos.map { $0.imagePath })
        let orphaned = filenames.subtracting(referencedFilenames)
        for filename in orphaned {
            let fileURL = directory.appendingPathComponent(filename)
            try? fileManager.removeItem(at: fileURL)
        }
    }
    func getTotalPhotoSize() throws -> Int64 {
        guard let directory = photoDirectoryURL() else { return 0 }
        
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        
        var totalSize: Int64 = 0
        for file in files {
            let attributes = try fileManager.attributesOfItem(atPath: file.path)
            if let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }

    func deleteAllLocalPhotos() throws {
        guard let directory = photoDirectoryURL() else { return }

        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }
    
    private func buildPhotoPayloadData(_ photo: ObservedBirdPhoto, for operation: SyncOperationType) -> Data? {
        var payload: [String: Any] = [
            "observed_bird_photo_id": photo.id.uuidString,
            "watchlist_entry_id": photo.watchlistEntry?.id.uuidString as Any,
            "image_path": photo.imagePath,
            "storage_url": photo.storageUrl as Any,
            "captured_at": photo.captured_at.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if operation == .delete {
            payload["deleted_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("WatchlistPhotoService failed to serialize photo payload: \(error.localizedDescription)")
            return nil
        }
    }
}
