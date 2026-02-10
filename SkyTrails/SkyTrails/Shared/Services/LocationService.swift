import Foundation
import CoreLocation
import MapKit

/// A centralized service for geocoding and location-related operations in the Watchlist module.
@MainActor
final class LocationService: NSObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    private var searchCompleter = MKLocalSearchCompleter()
    private var autocompleteContinuation: CheckedContinuation<[LocationSuggestion], Never>?
    
    /// Current device location (updated when location services are used)
    var currentLocation: CLLocationCoordinate2D?
    
    override private init() {
        super.init()
        searchCompleter.delegate = self
    }
    
    // MARK: - Core Types
    
    struct LocationData: Equatable {
        let displayName: String
        let lat: Double
        let lon: Double
    }
    
    struct LocationSuggestion: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let fullText: String
    }
    
    enum LocationError: Error {
        case geocodingFailed
        case locationAccessDenied
        case locationNotFound
        case serviceUnavailable
    }
    
    // MARK: - Geocoding Methods
    
    /// Forward geocoding: Convert search query to coordinates
    func geocode(query: String) async throws -> LocationData {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else {
                throw LocationError.locationNotFound
            }
            
            let name = item.name ?? query
            let coord = item.placemark.coordinate
            
            return LocationData(
                displayName: name,
                lat: coord.latitude,
                lon: coord.longitude
            )
        } catch {
            throw LocationError.geocodingFailed
        }
    }
    
    /// Reverse geocoding: Convert coordinates to place name
    func reverseGeocode(lat: Double, lon: Double) async -> String? {
        let location = CLLocation(latitude: lat, longitude: lon)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        
        do {
            let response = try await request.mapItems
            return response.first?.name
        } catch {
            print("❌ [LocationService] Reverse geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Current Location
    
    /// Get current device location with reverse-geocoded name
    func getCurrentLocation() async throws -> LocationData {
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // In a real app, we might wait for auth change, but for now we'll throw
            throw LocationError.locationAccessDenied
        case .restricted, .denied:
            throw LocationError.locationAccessDenied
        case .authorizedAlways, .authorizedWhenInUse:
            return try await withCheckedThrowingContinuation { continuation in
                LocationRequestDelegate.requestLocation(manager: locationManager) { result in
                    switch result {
                    case .success(let location):
                        Task {
                            let name = await self.reverseGeocode(
                                lat: location.coordinate.latitude,
                                lon: location.coordinate.longitude
                            ) ?? "Current Location"
                            
                            continuation.resume(returning: LocationData(
                                displayName: name,
                                lat: location.coordinate.latitude,
                                lon: location.coordinate.longitude
                            ))
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        @unknown default:
            throw LocationError.serviceUnavailable
        }
    }
    
    // MARK: - Autocomplete
    
    /// Get location suggestions for autocomplete
    func getAutocompleteSuggestions(for query: String) async -> [LocationSuggestion] {
        // Cancel any pending request to avoid leaks or out-of-order returns
        if let existing = autocompleteContinuation {
            existing.resume(returning: [])
            autocompleteContinuation = nil
        }
        
        if query.isEmpty { return [] }
        
        return await withCheckedContinuation { continuation in
            autocompleteContinuation = continuation
            searchCompleter.queryFragment = query
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension LocationService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.map { result in
            let text = result.subtitle.isEmpty ? result.title : "\(result.title) \(result.subtitle)"
            return LocationSuggestion(
                title: result.title,
                subtitle: result.subtitle,
                fullText: text
            )
        }
        autocompleteContinuation?.resume(returning: suggestions)
        autocompleteContinuation = nil
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Only report error if it's not a cancellation (though MKLocalSearchCompleter doesn't typically error on cancel)
        print("❌ [LocationService] Autocomplete failed: \(error.localizedDescription)")
        autocompleteContinuation?.resume(returning: [])
        autocompleteContinuation = nil
    }
}

// MARK: - Location Request Helper
private class LocationRequestDelegate: NSObject, CLLocationManagerDelegate {
    private var completion: (Result<CLLocation, Error>) -> Void
    private let manager: CLLocationManager
    
    static func requestLocation(manager: CLLocationManager, completion: @escaping (Result<CLLocation, Error>) -> Void) {
        let delegate = LocationRequestDelegate(manager: manager, completion: completion)
        manager.delegate = delegate
        manager.requestLocation()
        
        // Keep delegate alive until completion
        objc_setAssociatedObject(manager, "request_delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    }
    
    private init(manager: CLLocationManager, completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.manager = manager
        self.completion = completion
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            completion(.success(location))
        } else {
            completion(.failure(LocationService.LocationError.locationNotFound))
        }
        cleanup()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion(.failure(error))
        cleanup()
    }
    
    private func cleanup() {
        objc_setAssociatedObject(manager, "request_delegate", nil, .OBJC_ASSOCIATION_RETAIN)
    }
}
