import Foundation
import UIKit

@MainActor
final class WatchlistPresentationService {
    
    private let query: WatchlistQueryService
    private let persistence: WatchlistPersistenceService
    private let photoService: WatchlistPhotoService
    
    init(
        query: WatchlistQueryService,
        persistence: WatchlistPersistenceService,
        photoService: WatchlistPhotoService
    ) {
        self.query = query
        self.persistence = persistence
        self.photoService = photoService
    }
    
    // MARK: - ViewModel Creation
    
    func loadMyWatchlistViewModel(fetchWatchlists: () throws -> [Watchlist]) async throws -> WatchlistCellViewModel {
        let allLists = try fetchWatchlists()
        let dto = query.buildMyWatchlistDTO(from: allLists)
        
        async let unobservedImages = loadImages(paths: dto.unobservedPreviewImages)
        async let observedImages = loadImages(paths: dto.observedPreviewImages)
        
        let (unobservedImgs, observedImgs) = await (unobservedImages, observedImages)
        
        return WatchlistCellViewModel(
            title: dto.title,
            unobservedCount: dto.stats.totalCount - dto.stats.observedCount,
            observedCount: dto.stats.observedCount,
            totalCount: dto.stats.totalCount,
            unobservedImages: unobservedImgs,
            observedImages: observedImgs
        )
    }
    
    func loadCustomWatchlistViewModels(from dtos: [WatchlistSummaryDTO]) async -> [CustomWatchlistCellViewModel] {
        await withTaskGroup(of: (Int, CustomWatchlistCellViewModel).self) { group in
            for (index, dto) in dtos.enumerated() {
                group.addTask {
                    let coverImage = await self.loadImage(path: dto.image)
                    return (index, CustomWatchlistCellViewModel(
                        watchlistId: dto.legacyUUID,
                        title: dto.title,
                        subtitle: dto.subtitle,
                        dateText: dto.dateText,
                        coverImage: coverImage,
                        totalCount: dto.stats.totalCount,
                        observedCount: dto.stats.observedCount,
                        type: dto.type
                    ))
                }
            }
            
            var results: [(Int, CustomWatchlistCellViewModel)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map(\.1)
        }
    }
    
    func loadBirdEntryViewModels(from entries: [WatchlistEntry], shouldShowAvatars: Bool) async -> [BirdEntryCellViewModel] {
        await withTaskGroup(of: (Int, BirdEntryCellViewModel).self) { group in
            for (index, entry) in entries.enumerated() {
                group.addTask {
                    let birdImage = await self.loadImageForEntry(entry)
                    return await (index, BirdEntryCellViewModel(
                        entryId: entry.id,
                        birdName: entry.bird?.name ?? "Unknown",
                        birdImage: birdImage,
                        observationDate: Self.formatObservationDate(entry.observationDate),
                        location: Self.determineLocation(for: entry),
                        shouldShowAvatars: shouldShowAvatars,
                        avatarNames: entry.observedBy != nil ? [entry.observedBy!] : [],
                        status: entry.status
                    ))
                }
            }
            
            var results: [(Int, BirdEntryCellViewModel)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map(\.1)
        }
    }
    
    // MARK: - Image Loading
    
    func loadImages(paths: [String]) async -> [UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, path) in paths.enumerated() {
                group.addTask {
                    let image = await self.loadImage(path: path)
                    return (index, image)
                }
            }
            
            var results: [(Int, UIImage)] = []
            for await result in group {
                if let image = result.1 {
                    results.append((result.0, image))
                }
            }
            return results.sorted(by: { $0.0 < $1.0 }).map(\.1)
        }
    }
    
    func loadImage(path: String?) async -> UIImage? {
        guard let path = path, !path.isEmpty else {
            return nil
        }
        
        if let userPhoto = loadUserPhoto(named: path) {
            return userPhoto
        }
        
        if let assetImage = UIImage(named: path) {
            return assetImage
        }
        
        if let remoteImage = await IdentificationImageService.shared.image(for: path, shapeId: nil) {
            return remoteImage
        }
        
        return nil
    }
    
    func loadImageForEntry(_ entry: WatchlistEntry) async -> UIImage {
        if let photoPath = entry.photos?.first?.imagePath {
            if let userPhoto = loadUserPhoto(named: photoPath) {
                return userPhoto
            }
        }
        
        guard let bird = entry.bird else {
            return UIImage(systemName: "photo") ?? UIImage()
        }
        
        return await loadImage(path: bird.staticImageName) ?? UIImage(systemName: "photo") ?? UIImage()
    }
    
    func loadUserPhoto(named imageName: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDirectory = documentsPath.appendingPathComponent("ObservedBirdPhotos")
        let imagePath = photosDirectory.appendingPathComponent(imageName)
        
        return UIImage(contentsOfFile: imagePath.path)
    }
    
    // MARK: - Formatting Helpers
    
    static func formatObservationDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    static func determineLocation(for entry: WatchlistEntry) -> String? {
        if let userLocation = entry.locationDisplayName, !userLocation.isEmpty {
            return userLocation
        }
        if let likelySpot = entry.bird?.likelySpot {
            return likelySpot
        }
        return nil
    }
}
