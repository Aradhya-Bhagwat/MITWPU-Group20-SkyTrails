
import UIKit
import Foundation

// MARK: - View Models for Watchlist Feature
// These ViewModels are fully prepared by Manager/Services and ready for direct cell display

/// ViewModel for MyWatchlist collection view cell
struct WatchlistCellViewModel {
    let title: String
    let unobservedCount: Int
    let observedCount: Int
    let totalCount: Int
    let unobservedImages: [UIImage]  // Pre-loaded images
    let observedImages: [UIImage]    // Pre-loaded images
}

/// ViewModel for bird entry cells (table/collection view)
struct BirdEntryCellViewModel {
    let entryId: UUID
    let birdName: String
    let birdImage: UIImage           // Pre-loaded image
    let observationDate: String?     // Pre-formatted date
    let location: String?
    let shouldShowAvatars: Bool
    let avatarNames: [String]        // User avatar identifiers
    let status: WatchlistEntryStatus
}

/// ViewModel for custom watchlist collection view cell
struct CustomWatchlistCellViewModel {
    let watchlistId: UUID
    let title: String
    let subtitle: String             // Location
    let dateText: String
    let coverImage: UIImage?         // Pre-loaded cover image
    let totalCount: Int
    let observedCount: Int
    let type: WatchlistType
}

/// Result structure for filtered entries with all metadata
struct WatchlistEntriesResult {
    let observed: [WatchlistEntry]
    let unobserved: [WatchlistEntry]
    let observedCount: Int
    let unobservedCount: Int
    let totalCount: Int
    let title: String
    let shouldShowRecommendations: Bool
    let recommendedBirds: [Bird]
}
