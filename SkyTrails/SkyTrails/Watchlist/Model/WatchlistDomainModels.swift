//
//  WatchlistDomainModels.swift
//  SkyTrails
//
//  Created by SDC-USER on 02/02/26.
//

import Foundation

struct WatchlistSummaryDTO: Hashable {
    let id: UUID
    let title: String
    let subtitle: String // Location
    let dateText: String // "Oct - Nov"
    let image: String?
    let previewImages: [String] // For My Watchlist grid
    let stats: WatchlistStatsDTO
    let type: WatchlistType
}

struct WatchlistStatsDTO: Hashable {
    let observedCount: Int
    let totalCount: Int
    let rareCount: Int
}
