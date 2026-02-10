//
//  LocationPreferences.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/02/26.
//


//
//  LocationPreferences.swift
//  SkyTrails
//
//  User location preferences
//

import Foundation
import CoreLocation

final class LocationPreferences {
    static let shared = LocationPreferences()
    
    private let defaults = UserDefaults.standard
    private let homeLatKey = "kUserHomeLatitude"
    private let homeLonKey = "kUserHomeLongitude"
    private let homeNameKey = "kUserHomeLocationName"
    
    private init() {}
    
    var homeLocation: CLLocationCoordinate2D? {
        get {
            guard defaults.object(forKey: homeLatKey) != nil else { return nil }
            let lat = defaults.double(forKey: homeLatKey)
            let lon = defaults.double(forKey: homeLonKey)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            if let location = newValue {
                defaults.set(location.latitude, forKey: homeLatKey)
                defaults.set(location.longitude, forKey: homeLonKey)
            } else {
                defaults.removeObject(forKey: homeLatKey)
                defaults.removeObject(forKey: homeLonKey)
            }
        }
    }
    
    var homeLocationName: String? {
        get { defaults.string(forKey: homeNameKey) }
        set { defaults.set(newValue, forKey: homeNameKey) }
    }
    
    func setHomeLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) async {
        homeLocation = coordinate
        
        if let name = name {
            homeLocationName = name
        } else {
            // Reverse geocode to get name
            homeLocationName = await LocationService.shared.reverseGeocode(
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
        }
        
        print("🏠 [LocationPreferences] Home location set to: \(homeLocationName ?? "Unknown")")
    }
}