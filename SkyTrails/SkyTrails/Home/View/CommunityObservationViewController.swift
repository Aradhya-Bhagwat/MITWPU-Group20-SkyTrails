//
//  CommunityObservationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 08/01/26.
//

import UIKit

class CommunityObservationViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var locationNameLabel: UILabel!

    @IBOutlet weak var notesLabel: UILabel!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var timePicker: UIDatePicker!
    
    @IBOutlet weak var dateCardView: UIView!
    @IBOutlet weak var locationStackView: UIStackView!
    @IBOutlet weak var notesStackView: UIStackView!
    
    // Data
    var observation: CommunityObservation?
    var observationId: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI Setup
        view.backgroundColor = .systemGray6
        navigationItem.largeTitleDisplayMode = .never
        
        birdImageView.layer.cornerRadius = 24
        birdImageView.clipsToBounds = true
        
        // 1. Date Card Styling
        styleCard(dateCardView)
        
        // 2. Location Card Styling
        locationStackView.isLayoutMarginsRelativeArrangement = true
        locationStackView.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        locationStackView.addBackground(color: .white, cornerRadius: 20)
        
        // 3. Observation Notes Card Styling
        notesStackView.isLayoutMarginsRelativeArrangement = true
        notesStackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        notesStackView.addBackground(color: .white, cornerRadius: 20)
        
        if let obs = observation {
            configureView(with: obs)
        } else if let id = observationId {
            loadData(for: id)
        }
    }
    
    func styleCard(_ view: UIView?) {
        guard let view = view else { return }
        view.layer.cornerRadius = 20
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.masksToBounds = false
    }
    
    /// Loads data from local JSON file as requested
    func loadData(for id: String) {
        let coreData = DataLoader.load("home_data", as: CoreHomeData.self)
        if let found = coreData.community_observations?.first(where: { $0.observationId == id }) {
            self.observation = found
            configureView(with: found)
        } else {
            print("Observation with ID \(id) not found.")
        }
    }
    
    private func configureView(with observation: CommunityObservation) {
        self.title = observation.displayBirdName
        
        if let image = UIImage(named: observation.displayImageName) {
            birdImageView.image = image
        } else {
            birdImageView.image = UIImage(systemName: "photo")
        }
        
        userNameLabel.text = "by \(observation.username ?? "Unknown")"
        
        // Enable multiline for location
        locationNameLabel.numberOfLines = 0
        locationNameLabel.text = observation.location
        
        // Assuming subtitle could be coordinates or region, keeping it simple for now

		
        
        notesLabel.numberOfLines = 0
        notesLabel.text = observation.observationDescription ?? "No description available."
        
        if let dateString = observation.timestamp {
            // ISO8601 Parser
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                datePicker.date = date
                timePicker.date = date
            }
        }
        
        // Disable user interaction for detail view mode
        datePicker.isUserInteractionEnabled = false
        timePicker.isUserInteractionEnabled = false
    }
}

extension UIStackView {
    func addBackground(color: UIColor, cornerRadius: CGFloat) {
        let subView = UIView(frame: bounds)
        subView.backgroundColor = color
        subView.layer.cornerRadius = cornerRadius
        subView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(subView, at: 0)
        
        // Shadow for the stack view's background
        subView.layer.shadowColor = UIColor.black.cgColor
        subView.layer.shadowOpacity = 0.08
        subView.layer.shadowOffset = CGSize(width: 0, height: 4)
        subView.layer.shadowRadius = 12
        subView.layer.masksToBounds = false
    }
}
