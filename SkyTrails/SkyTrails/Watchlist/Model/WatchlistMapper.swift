//
//  WatchlistMapper.swift
//  SkyTrails
//
//  Created by SDC-USER on 05/02/26.
//

import Foundation

struct WatchlistMapper {
    
    static func buildMyWatchlistDTO(from allLists: [Watchlist]) -> WatchlistSummaryDTO {
        // Aggregate ALL entries from ALL watchlists
        let allEntries = allLists.flatMap { $0.entries ?? [] }
        
        // Remove duplicates by bird ID (keep observed status if exists)
        var uniqueEntries: [UUID: WatchlistEntry] = [:]
        for entry in allEntries {
            if let birdId = entry.bird?.id {
                if let existing = uniqueEntries[birdId] {
                    // Prefer observed status
                    if entry.status == .observed && existing.status != .observed {
                        uniqueEntries[birdId] = entry
                    }
                } else {
                    uniqueEntries[birdId] = entry
                }
            }
        }
        
        let uniqueEntriesArray = Array(uniqueEntries.values)
        
        // Calculate stats
        let observedCount = uniqueEntriesArray.filter { $0.status == .observed }.count
        let totalCount = uniqueEntriesArray.count
        let rareCount = uniqueEntriesArray.filter {
            $0.status == .observed &&
            ($0.bird?.rarityLevel == .rare || $0.bird?.rarityLevel == .very_rare)
        }.count
        
        let stats = WatchlistStatsDTO(
            observedCount: observedCount,
            totalCount: totalCount,
            rareCount: rareCount
        )
        
        // Get preview images (up to 4 unique birds)
        let previewImages = uniqueEntriesArray
            .compactMap { $0.bird?.staticImageName }
            .prefix(4)
            .map { String($0) }
        
        return WatchlistSummaryDTO(
            id: WatchlistConstants.myWatchlistID,
            title: "My Watchlist",
            subtitle: "All Birds",
            dateText: "",
            image: previewImages.first,
            previewImages: Array(previewImages),
            stats: stats,
            type: .my_watchlist
        )
    }
    
    static func toDTO(_ model: Watchlist) -> WatchlistSummaryDTO {
        let entries = model.entries ?? []
        let observed = entries.filter { $0.status == .observed }.count
        
        // Calculate Stats
        let stats = WatchlistStatsDTO(
            observedCount: observed,
            totalCount: entries.count,
            rareCount: 0 // Simplification for list view
        )
        
        // Determine Image
        var imagePath: String? = model.images?.first?.imagePath
        if imagePath == nil {
            imagePath = model.entries?.first?.bird?.staticImageName
        }
        
        // Preview Images (up to 4)
        let previewImages = entries.compactMap { $0.bird?.staticImageName }.prefix(4).map { String($0) }
        
        // Subtitle logic
        let subtitle = model.location ?? "Unknown Location"
        
        // Date Text
        let dateText: String
        if let start = model.startDate, let end = model.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            dateText = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            dateText = ""
        }
        
        return WatchlistSummaryDTO(
            id: model.id,
            title: model.title ?? "Untitled",
            subtitle: subtitle,
            dateText: dateText,
            image: imagePath,
            previewImages: Array(previewImages),
            stats: stats,
            type: model.type ?? .custom
        )
    }
}
