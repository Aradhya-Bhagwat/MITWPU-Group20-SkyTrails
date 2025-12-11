//
//  MapViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit
import MapKit
import CoreLocation
class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    var selectedCoordinate: CLLocationCoordinate2D?
    var hasShownSheet = false

    private let locationManager = CLLocationManager()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if !hasShownSheet {
              presentBottomSheet()
              hasShownSheet = true
          }

        mapView.mapType = .mutedStandard

        mapView.delegate = self
        locationManager.delegate = self
        
        locationManager.requestWhenInUseAuthorization()
        let tap = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tap)
             
        // Do any additional setup after loading the view.
    }
    

    
    @objc func mapTapped(_ sender: UITapGestureRecognizer){
       
        if sender.state == .ended {
            let point = sender.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            addPin(at: coord, title: "Selected Location")
       
           
          
        }
    }
    
    func addPin(at coordinate: CLLocationCoordinate2D, title: String) {
        let nonUserAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(nonUserAnnotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        mapView.addAnnotation(annotation)
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 12000, longitudinalMeters: 12000)
           mapView.setRegion(region, animated: true)
       
            }
    
    func presentBottomSheet() {
        let vc = storyboard?.instantiateViewController(withIdentifier: "LocationBottomSheetViewController") as! LocationBottomSheetViewController

        vc.selectedCoordinate = nil
        vc.delegate = self
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [
                .custom { _ in 120 },
                .medium(),
                .large()
            ]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(vc, animated: true)
    }

 
    
}

extension MapViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            mapView.showsUserLocation = true
            manager.startUpdatingLocation()
        }else if status == .denied || status == .restricted {
            print("Location access denied")
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location  = locations.last else { return }
        print("user location",location.coordinate)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
  

}

extension MapViewController: LocationSearchDelegate {
   
    func locationSelected(_ coordinate: CLLocationCoordinate2D, name: String?) {
        addPin(at: coordinate, title: name ?? "Selected Place")
        
    }
}

