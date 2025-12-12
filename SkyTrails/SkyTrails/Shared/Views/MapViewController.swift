//
//  MapViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit
import MapKit
import CoreLocation
class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    private let locationManager = CLLocationManager()
    private var isInMoveMode = false
    private var movingAnnotation: MKPointAnnotation?
    private var searchSheetVC: LocationBottomSheetViewController?
    private var detailsSheetVC: LocationDetailsViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        locationManager.delegate = self
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        locationManager.requestWhenInUseAuthorization()

        let tap = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tap)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentSearchSheetIfNeeded()
    }

    private func presentSearchSheetIfNeeded() {
        if searchSheetVC != nil { return }

        let vc = storyboard?.instantiateViewController(withIdentifier: "LocationBottomSheetViewController") as! LocationBottomSheetViewController
        vc.delegate = self
        searchSheetVC = vc

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(vc, animated: true)
    }

    @objc func mapTapped(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        let point = sender.location(in: mapView)
        let coord = mapView.convert(point, toCoordinateFrom: mapView)

        if isInMoveMode {
            guard let moving = movingAnnotation else {
                endMoveMode()
                return
            }
            moving.coordinate = coord
            isInMoveMode = false
            reverseGeocodeTappedLocation(coord)
            movingAnnotation = nil
            return
        }

        addPin(at: coord, title: "Dropped Pin")
        reverseGeocodeTappedLocation(coord)
    }

    func addPin(at coordinate: CLLocationCoordinate2D, title: String) {
        let nonUserPins = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(nonUserPins)

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        mapView.addAnnotation(annotation)
        mapView.setCenter(coordinate, animated: true)
    }

    func reverseGeocodeTappedLocation(_ coord: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self = self else { return }
            if let place = placemarks?.first {
                let name = place.name ?? "Dropped Pin"
                let address = place.formattedAddress
                self.showLocationDetails(for: coord, name: name, address: address)
            } else {
                self.showLocationDetails(for: coord, name: "Dropped Pin", address: "Unknown Address")
            }
        }
    }

    func showLocationDetails(for coordinate: CLLocationCoordinate2D,
                             name: String,
                             address: String) {

        if let old = detailsSheetVC {
            old.dismiss(animated: false)
        }

        let vc = storyboard?.instantiateViewController(withIdentifier: "LocationDetailsVC") as! LocationDetailsViewController
        vc.coordinate = coordinate
        vc.locationName = name
        vc.addressString = address
        vc.delegate = self
        detailsSheetVC = vc

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(vc, animated: true)
    }
    private func findAnnotation(at coordinate: CLLocationCoordinate2D) -> MKPointAnnotation? {
        return mapView.annotations.compactMap { $0 as? MKPointAnnotation }.first(where: {
            abs($0.coordinate.latitude - coordinate.latitude) < 0.000001 &&
            abs($0.coordinate.longitude - coordinate.longitude) < 0.000001
        })
    }

    private func beginMoveMode(for coordinate: CLLocationCoordinate2D) {
        guard let ann = findAnnotation(at: coordinate) else { return }

        movingAnnotation = ann
        isInMoveMode = true

        let alert = UIAlertController(
            title: "Move Pin",
            message: "Tap on the map where you want to move the pin.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.endMoveMode()
        })

        (self.detailsSheetVC ?? self.searchSheetVC)?.present(alert, animated: true)
    }
    private func endMoveMode() {
        isInMoveMode = false
        movingAnnotation = nil
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }

        let identifier = "redPin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            pinView?.canShowCallout = true
            pinView?.pinTintColor = .red
        } else {
            pinView?.annotation = annotation
        }

        return pinView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let coord = view.annotation?.coordinate else { return }
        reverseGeocodeTappedLocation(coord)
    }
}

extension MapViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            mapView.showsUserLocation = true
            locationManager.startUpdatingLocation()
        }
    }
}

extension MapViewController: LocationDetailsDelegate {
    func removePin(at coordinate: CLLocationCoordinate2D) {
        if let ann = findAnnotation(at: coordinate) {
            mapView.removeAnnotation(ann)
        }
    }

    func startMovePin(at coordinate: CLLocationCoordinate2D) {
        beginMoveMode(for: coordinate)
    }
}

extension MapViewController: LocationSearchDelegate {
    func locationSelected(_ coordinate: CLLocationCoordinate2D, name: String?) {
        addPin(at: coordinate, title: name ?? "Selected Place")
        reverseGeocodeTappedLocation(coordinate)
    }
}

extension CLPlacemark {
    var formattedAddress: String {
        [
            name,
            thoroughfare,
            subThoroughfare,
            locality,
            administrativeArea,
            postalCode,
            country
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}

