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
    private var locationBackgroundView: UIView?
    private var notesBackgroundView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()

        navigationItem.largeTitleDisplayMode = .never
        
        birdImageView.layer.cornerRadius = 24
        birdImageView.clipsToBounds = true
        
        locationStackView.isLayoutMarginsRelativeArrangement = true
        locationStackView.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)

        notesStackView.isLayoutMarginsRelativeArrangement = true
        notesStackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        setupStackBackgrounds()
        applySemanticAppearance()
        
        if let obs = observation {
            configureView(with: obs)
        } else if let id = observationId {
            loadData(for: id)
        }
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }
    
    private func setupStackBackgrounds() {
        locationBackgroundView = locationStackView.ensureBackgroundView()
        notesBackgroundView = notesStackView.ensureBackgroundView()
        locationBackgroundView?.layer.cornerRadius = 20
        notesBackgroundView?.layer.cornerRadius = 20
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

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        view.backgroundColor = .systemBackground
        dateCardView.backgroundColor = cardColor
        dateCardView.layer.cornerRadius = 20
        dateCardView.layer.masksToBounds = false

        locationBackgroundView?.backgroundColor = cardColor
        locationBackgroundView?.layer.masksToBounds = false
        notesBackgroundView?.backgroundColor = cardColor
        notesBackgroundView?.layer.masksToBounds = false

        [userNameLabel, locationNameLabel, notesLabel].forEach { $0?.textColor = .label }
        datePicker.tintColor = .systemBlue
        timePicker.tintColor = .systemBlue
        datePicker.overrideUserInterfaceStyle = .unspecified
        timePicker.overrideUserInterfaceStyle = .unspecified

        if isDarkMode {
            [dateCardView, locationBackgroundView, notesBackgroundView].forEach { view in
                view?.layer.shadowOpacity = 0
                view?.layer.shadowRadius = 0
                view?.layer.shadowOffset = .zero
                view?.layer.shadowPath = nil
            }
        } else {
            [dateCardView, locationBackgroundView, notesBackgroundView].forEach { view in
                view?.layer.shadowColor = UIColor.black.cgColor
                view?.layer.shadowOpacity = 0.08
                view?.layer.shadowOffset = CGSize(width: 0, height: 4)
                view?.layer.shadowRadius = 12
                view?.layer.shadowPath = nil
            }
        }
    }
}

extension UIStackView {
    func ensureBackgroundView() -> UIView {
        if let existing = subviews.first(where: { $0.tag == 9991 }) {
            return existing
        }
        let subView = UIView(frame: bounds)
        subView.tag = 9991
        subView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(subView, at: 0)
        return subView
    }
}
