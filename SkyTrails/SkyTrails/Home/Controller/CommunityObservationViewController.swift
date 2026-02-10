//
//  CommunityObservationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 08/01/26.
//

import UIKit

class CommunityObservationViewController: UIViewController {

    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var locationNameLabel: UILabel!
    @IBOutlet weak var notesLabel: UILabel!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var timePicker: UIDatePicker!
    @IBOutlet weak var dateCardView: UIView!
    @IBOutlet weak var locationStackView: UIStackView!
    @IBOutlet weak var notesStackView: UIStackView!
    
    var observation: CommunityObservation?
    var observationId: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGray6
        navigationItem.largeTitleDisplayMode = .never
        
        birdImageView.layer.cornerRadius = 24
        birdImageView.clipsToBounds = true
        
        styleCard(dateCardView)
        
        locationStackView.isLayoutMarginsRelativeArrangement = true
        locationStackView.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        locationStackView.addBackground(color: .white, cornerRadius: 20)
        
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
    
    func loadData(for id: String) {
        print("Observation with ID \(id) not found.")
    }
    
    private func configureView(with observation: CommunityObservation) {
        self.title = observation.displayBirdName
        
        if let image = UIImage(named: observation.displayImageName) {
            birdImageView.image = image
        } else {
            birdImageView.image = UIImage(systemName: "photo")
        }
        
        userNameLabel.text = "by \(observation.username ?? "Unknown")"
        locationNameLabel.numberOfLines = 0
        locationNameLabel.text = observation.location
        notesLabel.numberOfLines = 0
        notesLabel.text = observation.observationDescription ?? "No description available."
        
        datePicker.date = observation.observedAt
        timePicker.date = observation.observedAt
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
        subView.layer.shadowColor = UIColor.black.cgColor
        subView.layer.shadowOpacity = 0.08
        subView.layer.shadowOffset = CGSize(width: 0, height: 4)
        subView.layer.shadowRadius = 12
        subView.layer.masksToBounds = false
    }
}
