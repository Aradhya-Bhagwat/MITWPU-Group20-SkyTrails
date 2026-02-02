//
//  WatchlistRepository.swift
//  SkyTrails
//
//  Created by SDC-USER on 02/02/26.
//

import Foundation

protocol WatchlistRepository {
    func loadDashboardData() async throws -> (myWatchlist: WatchlistSummaryDTO?, custom: [WatchlistSummaryDTO], shared: [WatchlistSummaryDTO], globalStats: WatchlistStatsDTO)
    func deleteWatchlist(id: UUID) async throws
    func ensureMyWatchlistExists() async throws -> UUID
    func getPersonalWatchlists() -> [Watchlist]
}
