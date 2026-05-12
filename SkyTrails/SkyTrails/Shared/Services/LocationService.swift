import Foundation
import CoreLocation
import MapKit

protocol LocationServiceProtocol: Sendable {
    var currentLocation: CLLocationCoordinate2D? { get }
    func parseCoordinate(from locationString: String) -> CLLocationCoordinate2D?
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance
}
@MainActor
final class LocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {
    static let shared = LocationService()
    static let authorizationDidChangeNotification = Notification.Name("LocationServiceAuthorizationDidChange")
    
    private let locationManager = CLLocationManager()
    private var searchCompleter = MKLocalSearchCompleter()
    private var autocompleteContinuation: CheckedContinuation<[LocationSuggestion], Never>?
    private let logger: LoggingServiceProtocol
    var currentLocation: CLLocationCoordinate2D?
    
    var isAuthorized: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    
    init(logger: LoggingServiceProtocol? = nil) {
        self.logger = logger ?? LoggingService.shared
        super.init()
        searchCompleter.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        let status = locationManager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }
    
    func parseCoordinate(from locationString: String) -> CLLocationCoordinate2D? {
        let components = locationString.components(separatedBy: ",")
        guard components.count == 2,
              let lat = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(components[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)
    }
    
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

    func primeAuthorizationIfNeeded() async {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            _ = await withCheckedContinuation { continuation in
                AuthorizationRequestDelegate.requestAuthorization(manager: locationManager) { _ in
                    continuation.resume(returning: ())
                }
            }
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

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
            let coord = item.location.coordinate
            
            return LocationData(
                displayName: name,
                lat: coord.latitude,
                lon: coord.longitude
            )
        } catch {
            throw LocationError.geocodingFailed
        }
    }
    func reverseGeocode(lat: Double, lon: Double) async -> String? {
        let location = CLLocation(latitude: lat, longitude: lon)

        do {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else { return nil }

            return mapItem.addressRepresentations?.cityName
                ?? mapItem.name
                ?? mapItem.address?.shortAddress
                ?? mapItem.address?.fullAddress
                ?? mapItem.addressRepresentations?.regionName
        } catch {
            logger.log(error: error, context: "LocationService.reverseGeocode")
            return nil
        }
    }
    func getCurrentLocation() async throws -> LocationData {
        try await ensureLocationAuthorization()
        
        return try await withCheckedThrowingContinuation { continuation in
            let oneTimeManager = CLLocationManager()
            oneTimeManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            
            LocationRequestDelegate.requestLocation(manager: oneTimeManager) { result in
                switch result {
                case .success(let location):
                    Task {
                        // Sync updated location to shared state
                        await MainActor.run { self.currentLocation = location.coordinate }

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
                    if let clError = error as? CLError {
                        switch clError.code {
                        case .denied:
                            continuation.resume(throwing: LocationError.locationAccessDenied)
                        case .locationUnknown:
                            continuation.resume(throwing: LocationError.locationNotFound)
                        default:
                            continuation.resume(throwing: LocationError.serviceUnavailable)
                        }
                    } else {
                        continuation.resume(throwing: LocationError.serviceUnavailable)
                    }
                }
            }
        }
    }

    private func ensureLocationAuthorization() async throws {
        let currentStatus = locationManager.authorizationStatus
        switch currentStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .restricted, .denied:
            throw LocationError.locationAccessDenied
        case .notDetermined:
            let resolvedStatus = await withCheckedContinuation { continuation in
                AuthorizationRequestDelegate.requestAuthorization(manager: locationManager) { status in
                    continuation.resume(returning: status)
                }
            }

            switch resolvedStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                return
            case .restricted, .denied:
                throw LocationError.locationAccessDenied
            case .notDetermined:
                throw LocationError.serviceUnavailable
            @unknown default:
                throw LocationError.serviceUnavailable
            }
        @unknown default:
            throw LocationError.serviceUnavailable
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        guard manager === locationManager else { return }
        currentLocation = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard manager === locationManager else { return }
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager === locationManager else { return }
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
        NotificationCenter.default.post(name: Self.authorizationDidChangeNotification, object: nil)
    }
    func getAutocompleteSuggestions(for query: String) async -> [LocationSuggestion] {
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
        logger.log(error: error, context: "LocationService.autocomplete")
        autocompleteContinuation?.resume(returning: [])
        autocompleteContinuation = nil
    }
}
private class LocationRequestDelegate: NSObject, CLLocationManagerDelegate {
    private var completion: (Result<CLLocation, Error>) -> Void
    private let manager: CLLocationManager
    private var isResolved = false
    
    static func requestLocation(manager: CLLocationManager, completion: @escaping (Result<CLLocation, Error>) -> Void) {
        let delegate = LocationRequestDelegate(manager: manager, completion: completion)
        manager.delegate = delegate
        manager.requestLocation()
        objc_setAssociatedObject(manager, "request_delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    }
    
    private init(manager: CLLocationManager, completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.manager = manager
        self.completion = completion
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isResolved else { return }
        if let location = locations.last {
            completion(.success(location))
        } else {
            completion(.failure(LocationService.LocationError.locationNotFound))
        }
        cleanup()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !isResolved else { return }
        completion(.failure(error))
        cleanup()
    }
    
    private func cleanup() {
        isResolved = true
        objc_setAssociatedObject(manager, "request_delegate", nil, .OBJC_ASSOCIATION_RETAIN)
    }
}

private class AuthorizationRequestDelegate: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var completion: (CLAuthorizationStatus) -> Void
    private var isResolved = false

    static func requestAuthorization(manager: CLLocationManager, completion: @escaping (CLAuthorizationStatus) -> Void) {
        let delegate = AuthorizationRequestDelegate(manager: manager, completion: completion)
        manager.delegate = delegate
        manager.requestWhenInUseAuthorization()
        objc_setAssociatedObject(manager, "auth_request_delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    }

    private init(manager: CLLocationManager, completion: @escaping (CLAuthorizationStatus) -> Void) {
        self.manager = manager
        self.completion = completion
        super.init()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !isResolved else { return }
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        completion(status)
        cleanup()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard !isResolved else { return }
        guard status != .notDetermined else { return }
        completion(status)
        cleanup()
    }

    private func cleanup() {
        isResolved = true
        objc_setAssociatedObject(manager, "auth_request_delegate", nil, .OBJC_ASSOCIATION_RETAIN)
    }
}
