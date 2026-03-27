import Foundation
import CoreLocation
import Observation

@Observable
final class LocationCacheManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    
    var currentLocation: CLLocation?
    
    private let lastLatKey = "com.skytrails.lastFetchedLat"
    private let lastLngKey = "com.skytrails.lastFetchedLng"
    private let lastTimestampKey = "com.skytrails.lastFetchedTimestamp"
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func shouldRefreshData(currentLocation: CLLocation) -> Bool {
        let lastLat = defaults.double(forKey: lastLatKey)
        let lastLng = defaults.double(forKey: lastLngKey)
        let lastTimestampValue = defaults.double(forKey: lastTimestampKey)
        
        // Return true if we have no previous fetch data
        guard lastTimestampValue != 0 else { return true }
        
        let lastLocation = CLLocation(latitude: lastLat, longitude: lastLng)
        let lastDate = Date(timeIntervalSince1970: lastTimestampValue)
        
        let distance = currentLocation.distance(from: lastLocation) // meters
        let timeElapsed = Date().timeIntervalSince(lastDate) // seconds
        
        let fiveKilometers: Double = 5000
        let sixHours: Double = 6 * 60 * 60
        
        return distance > fiveKilometers || timeElapsed > sixHours
    }
    
    func updateCache(location: CLLocation) {
        defaults.set(location.coordinate.latitude, forKey: lastLatKey)
        defaults.set(location.coordinate.longitude, forKey: lastLngKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastTimestampKey)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}
