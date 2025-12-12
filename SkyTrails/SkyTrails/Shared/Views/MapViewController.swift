//
//  MapViewController.swift
//  SkyTrails
//

import UIKit
import MapKit
import CoreLocation

// ------------------------
// MARK: - Delegates
// ------------------------

protocol MapSelectionDelegate: AnyObject {
    func didSelectMapLocation(_ name: String)
}

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    private let locationManager = CLLocationManager()

    weak var delegate: MapSelectionDelegate?
    var selectedLocationName: String?

    @IBOutlet weak var searchPillView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRightTickButton()

        mapView.delegate = self
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        styleFloatingSearchBar()
        searchBar.delegate = self

        // Tap to add pin
        let tap = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tap)
    }

    // --------------------------------------------------------
    // MARK: - UI
    // --------------------------------------------------------

    private func styleFloatingSearchBar() {
        searchPillView.layer.cornerRadius = 28
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        searchBar.searchBarStyle = .minimal
        searchBar.searchTextField.textColor = .black
    }

    private func setupRightTickButton() {
        let button = UIButton(type: .system)
  
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "checkmark", withConfiguration: config), for: .normal)
        button.tintColor = .black

        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

    // --------------------------------------------------------
    // MARK: - Map Interactions
    // --------------------------------------------------------

    @objc func mapTapped(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: mapView)
        let coord = mapView.convert(point, toCoordinateFrom: mapView)

        addPin(at: coord)
        reverseGeocodeTappedLocation(coord)
    }
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

    func addPin(at coordinate: CLLocationCoordinate2D) {
        mapView.removeAnnotations(mapView.annotations)

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        mapView.setCenter(coordinate, animated: true)
    }

    func reverseGeocodeTappedLocation(_ coord: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) {
            [weak self] placemarks, _ in
            guard let self = self else { return }

            if let place = placemarks?.first {
                let name = place.name ?? "Location"
                self.selectedLocationName = name
                self.searchBar.text = name
            }
        }
    }

    // --------------------------------------------------------
    // MARK: - Tick Button
    // --------------------------------------------------------

    @objc private func nextTapped() {
        guard let name = selectedLocationName else { return }
        delegate?.didSelectMapLocation(name)
        navigationController?.popViewController(animated: true)
    }
}

// ------------------------------------------------------------
// MARK: - MKMapViewDelegate
// ------------------------------------------------------------

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let coord = view.annotation?.coordinate {
            reverseGeocodeTappedLocation(coord)
        }
    }
}

// ------------------------------------------------------------
// MARK: - CLLocationManagerDelegate
// ------------------------------------------------------------

extension MapViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
}

// ------------------------------------------------------------
// MARK: - UISearchBarDelegate (Bottom Sheet Trigger)
// ------------------------------------------------------------

extension MapViewController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {

        // Present bottom sheet for searching
        let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "LocationBottomSheetViewController")
            as! LocationBottomSheetViewController

        vc.delegate = self

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(vc, animated: true)
        return false
    }
}

// ------------------------------------------------------------
// MARK: - LocationSearchDelegate
// ------------------------------------------------------------

extension MapViewController: LocationSearchDelegate {
    func locationSelected(_ coordinate: CLLocationCoordinate2D, name: String?) {

        let finalName = name ?? "Selected Place"

        selectedLocationName = finalName
        searchBar.text = finalName

        addPin(at: coordinate)
        reverseGeocodeTappedLocation(coordinate)   // optional second pass
    }
}
