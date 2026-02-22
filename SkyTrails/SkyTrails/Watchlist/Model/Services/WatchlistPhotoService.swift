//
//  WatchlistPhotoService.swift
//  SkyTrails
//
//  Photo attachment and management for observed bird entries
//  Strict MVC Refactoring
//

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
    
    // MARK: - Photo Attachment
    
    /// Save photo to disk and attach to entry
    func attachPhoto(
        to entryID: UUID,
        image: UIImage,
        capturedAt: Date? = nil
    ) throws -> ObservedBirdPhoto {
        guard let entry = try persistence.fetchEntry(id: entryID) else {
            throw WatchlistError.entryNotFound(entryID)
        }
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        
        // Save image to disk
        do {
            try saveImageToDisk(image: image, filename: filename)
        } catch {
            throw WatchlistError.photoAttachmentFailed(underlying: error)
        }
        
        // Create photo entity
        let photo = ObservedBirdPhoto(watchlistEntry: entry, imagePath: filename)
        photo.captured_at = capturedAt
        
        context.insert(photo)
        
        do {
            try context.save()
        } catch {
            // Cleanup disk file if database save fails
            try? deleteImageFromDisk(filename: filename)
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        
        print("📸 [PhotoService] Photo attached to entry \(entryID): \(filename)")
        return photo
    }
    
    /// Attach existing photo file to entry
    func attachExistingPhoto(
        to entryID: UUID,
        imagePath: String,
        capturedAt: Date? = nil
    ) throws -> ObservedBirdPhoto {
        guard let entry = try persistence.fetchEntry(id: entryID) else {
            throw WatchlistError.entryNotFound(entryID)
        }
        
        // Verify file exists
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
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        
        print("📸 [PhotoService] Existing photo attached to entry \(entryID): \(imagePath)")
        return photo
    }
    
    // MARK: - Photo Deletion
    
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

        // Queue remote delete before removing local entity
        let photoToDelete = photo
        Task {
            await BackgroundSyncAgent.shared.queuePhoto(photoToDelete, operation: .delete)
        }
        
        // Delete from database
        context.delete(photo)
        
        do {
            try context.save()
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        
        // Delete from disk
        try? deleteImageFromDisk(filename: imagePath)
        
        print("🗑️ [PhotoService] Deleted photo: \(imagePath)")
    }
    
    func deleteAllPhotos(for entryID: UUID) throws {
        guard let entry = try persistence.fetchEntry(id: entryID) else {
            throw WatchlistError.entryNotFound(entryID)
        }
        
        let photos = entry.photos ?? []
        let imagePaths = photos.map { $0.imagePath }

        for photo in photos {
            let photoToDelete = photo
            Task {
                await BackgroundSyncAgent.shared.queuePhoto(photoToDelete, operation: .delete)
            }
        }
        
        // Delete from database
        for photo in photos {
            context.delete(photo)
        }
        
        do {
            try context.save()
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
        
        // Delete from disk
        for imagePath in imagePaths {
            try? deleteImageFromDisk(filename: imagePath)
        }
        
        print("🗑️ [PhotoService] Deleted \(photos.count) photos for entry \(entryID)")
    }
    
    // MARK: - Photo Retrieval
    
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
    
    // MARK: - Disk I/O
    
    private func saveImageToDisk(image: UIImage, filename: String) throws {
        guard let directory = photoDirectoryURL() else {
            throw NSError(domain: "WatchlistPhotoService", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Could not access photo directory"
            ])
        }
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // Convert to JPEG data
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "WatchlistPhotoService", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Could not convert image to JPEG"
            ])
        }
        
        // Write to disk
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
    
    // MARK: - Cleanup
    
    /// Remove orphaned photo files from disk (files not referenced in database)
    func cleanupOrphanedPhotos() throws {
        guard let directory = photoDirectoryURL() else { return }
        
        // Get all photo files on disk
        let filesOnDisk = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let filenames = Set(filesOnDisk.map { $0.lastPathComponent })
        
        // Get all photo records in database
        let descriptor = FetchDescriptor<ObservedBirdPhoto>()
        let photos = try context.fetch(descriptor)
        let referencedFilenames = Set(photos.map { $0.imagePath })
        
        // Find orphaned files
        let orphaned = filenames.subtracting(referencedFilenames)
        
        print("🧹 [PhotoService] Found \(orphaned.count) orphaned photo files")
        
        // Delete orphaned files
        for filename in orphaned {
            let fileURL = directory.appendingPathComponent(filename)
            try? fileManager.removeItem(at: fileURL)
            print("🗑️ [PhotoService] Deleted orphaned file: \(filename)")
        }
    }
    
    /// Get total disk space used by photos
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
}
