//
//  BirdDetailViewController.swift
//  SkyTrails
//
//  Created by Gemini on 07/12/25.
//

import UIKit

class BirdDetailViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var visualEffectView: UIVisualEffectView!
    @IBOutlet weak var headerIconView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scientificNameLabel: UILabel!
    
    // Container for form inputs
    @IBOutlet weak var formStackView: UIStackView!
    
    // Inputs (We will manipulate these or their containers)
    @IBOutlet weak var nameTextField: UITextField! // For "Create Watchlist" mode
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    // MARK: - Properties
    var bird: Bird?
    var mode: WatchlistMode = .observed
    weak var coordinator: WatchlistCoordinator?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureData()
    }
    
    private func setupUI() {
        // Default State
        nameTextField.isHidden = true
        
        // Navigation
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
        
        switch mode {
        case .observed, .create:
            setupLiquidGlassMode()
        case .unobserved:
            setupImageMode()
        }
        
        if mode == .create {
            title = "New Watchlist"
            nameTextField.isHidden = false
            titleLabel.isHidden = true // Hide bird title
            scientificNameLabel.isHidden = true
        } else {
            title = "Log Observation"
        }
    }
    
    private func setupLiquidGlassMode() {
        // Show blur, show icon, set placeholder image or gradient
        visualEffectView.isHidden = false
        headerIconView.isHidden = false
        headerIconView.image = UIImage(systemName: "rectangle.stack.badge.plus")
        
        // Set a background for the glass effect
        headerImageView.image = UIImage(named: "AsianFairyBluebird") // Fallback/Ambient
        headerImageView.contentMode = .scaleAspectFill
    }
    
    private func setupImageMode() {
        // Hide blur, hide icon, show bird image
        visualEffectView.isHidden = true
        headerIconView.isHidden = true
        headerImageView.contentMode = .scaleAspectFill
    }
    
    private func configureData() {
        if let bird = bird {
            titleLabel.text = bird.name
            scientificNameLabel.text = bird.scientificName
            
            if mode == .unobserved, let imageName = bird.images.first {
                headerImageView.image = UIImage(named: imageName)
            }
        }
    }
    
    @IBAction func didTapDate(_ sender: Any) {
        // Show Date Picker logic
    }
    
    @IBAction func didTapLocation(_ sender: Any) {
        // Show Location Logic
    }
    
    @objc private func didTapSave() {
        // Logic to save data...
        
        // Advance the loop
        coordinator?.showNextInLoop()
    }
}
