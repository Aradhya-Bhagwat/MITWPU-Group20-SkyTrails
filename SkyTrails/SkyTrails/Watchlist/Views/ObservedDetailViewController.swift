//
//  ObservedDetailViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 09/12/25.
//


//
//  ObservedDetailViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 09/12/25.
//


import UIKit

class ObservedDetailViewController: UIViewController {
	
		    // MARK: - Data Dependency
		    // This is how we pass data into this screen
		    var bird: Bird?
		    weak var coordinator: WatchlistCoordinator?
		    
		    // MARK: - IBOutlets
		    // Connect these to your Storyboard elements
		    @IBOutlet weak var birdImageView: UIImageView!
		    @IBOutlet weak var startLabel: UILabel! // The label inside the Start Date row
		    @IBOutlet weak var endLabel: UILabel!   // The label inside the End Date row
		    @IBOutlet weak var startDatePicker: UIDatePicker!
		    @IBOutlet weak var endDatePicker: UIDatePicker!
		    @IBOutlet weak var notesTextView: UITextView!
		    @IBOutlet weak var searchTextField: UITextField!
            @IBOutlet weak var detailsCardView: UIView!
            @IBOutlet weak var locationCardView: UIView!
		    
		    // MARK: - Lifecycle
		    override func viewDidLoad() {
		        super.viewDidLoad()
		        
		        // 1. Setup the visual styling (Round corners, shadows)
		        setupStyling()
		        
		        // 2. Load the data if it exists
		        if let birdData = bird {
		            configure(with: birdData)
		        }
		        
		        // 3. Setup Navigation
		        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
		        navigationItem.rightBarButtonItem = saveButton
		    }
		    
		    @objc func didTapSave() {
		        guard var updatedBird = bird else { return }
		        
		        // Update dates
		        updatedBird.date = [startDatePicker.date, endDatePicker.date]
		        
		        // Update location (simple string append/replace for now)
		        if let loc = searchTextField.text, !loc.isEmpty {
		            updatedBird.location = [loc]
		        }
		        
		        coordinator?.saveBirdDetails(bird: updatedBird)
		    }
		    
		    // MARK: - Data Population
            func configure(with bird: Bird) {
			// 1. Set Navigation Title
		self.navigationItem.title = bird.name
		
			// 2. Load Image (Safely)
		if let imageName = bird.images.first {
			birdImageView.image = UIImage(named: imageName)
		} else {
				// Fallback if array is empty
			birdImageView.image = UIImage(systemName: "photo")
		}
		
			// 3. Set Dates
			// Logic: Use first date for Start, last date for End.
			// If only 1 date exists, use it for both.
		if let firstDate = bird.date.first {
			startDatePicker.date = firstDate
		}
		
		if let lastDate = bird.date.last {
			endDatePicker.date = lastDate
		}
		
			// 4. Set Location
			// Pre-fill the search bar with the saved location
		if let locationName = bird.location.first {
			searchTextField.text = locationName
		}
		
			// 5. Notes?
			// Your Bird model currently doesn't have a 'notes' field.
			// I have left the placeholder text, but if you add 'var notes: String?'
			// to your model later, map it here:
			// notesTextView.text = bird.notes ?? "Add notes..."
	}
	
		// MARK: - Styling (From previous step)
	func setupStyling() {
			// 1. Background
		view.backgroundColor = .systemGray6 // Light gray background
		
			// 2. Bird Image
		birdImageView.layer.cornerRadius = 24
		birdImageView.clipsToBounds = true
		
			// 3. Search Bar Styling
		searchTextField.layer.cornerRadius = 25 // Pill shape (half of height 50)
		searchTextField.clipsToBounds = true
			// Add a subtle shadow to the search bar
		searchTextField.layer.shadowColor = UIColor.black.cgColor
		searchTextField.layer.shadowOpacity = 0.05
		searchTextField.layer.shadowOffset = CGSize(width: 0, height: 2)
		searchTextField.layer.shadowRadius = 4
		searchTextField.layer.masksToBounds = false // Needed for shadow
		
			// 4. Cards (Details & Location) styling helper
		styleCard(detailsCardView)
		styleCard(locationCardView)
	}
	
	func styleCard(_ view: UIView) {
		view.layer.cornerRadius = 20
		view.backgroundColor = .white
		
			// The Elite Shadow
		view.layer.shadowColor = UIColor.black.cgColor
		view.layer.shadowOpacity = 0.08
		view.layer.shadowOffset = CGSize(width: 0, height: 4)
		view.layer.shadowRadius = 12
		view.layer.masksToBounds = false
	}
}
