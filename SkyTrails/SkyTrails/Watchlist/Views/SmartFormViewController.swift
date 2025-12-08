	//
	//  SmartFormViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 08/12/25.
	//

import UIKit

class SmartFormViewController: UIViewController {
	
		// MARK: - Outlets
	@IBOutlet weak var formStackView: UIStackView!
	
		// Header
	@IBOutlet weak var headerImageView: UIImageView!
	@IBOutlet weak var visualEffectView: UIVisualEffectView!
	@IBOutlet weak var headerIconView: UIImageView!
	
		// Name Section
	//@IBOutlet weak var nameWrapper: UIView!
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var titleLabel: UILabel!
	
		// Date Section
	//@IBOutlet weak var startDateLabel: UILabel?
	@IBOutlet weak var datePicker: UIDatePicker!
	//@IBOutlet weak var endDateRow: UIView?
	//@IBOutlet weak var endDateLabel: UILabel?
	
		// Location Section
	@IBOutlet weak var locationLabel: UILabel!
	//@IBOutlet weak var locationSearchWrapper: UIView?
	//@IBOutlet weak var locationActionsStack: UIStackView?
	
	@IBOutlet weak var scientificNameLabel: UILabel!
	
		// MARK: - Properties
	weak var coordinator: WatchlistCoordinator?
	var bird: Bird?
	var mode: FormMode = .knownSpecies
	
	enum FormMode {
		case knownSpecies // Corresponds to .unobserved in Coordinator
		case newSpecies   // Corresponds to .observed in Coordinator
		case newWatchlist // Corresponds to .create in Coordinator
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		populateData()
	}
	
	private func setupUI() {
			// Sets standard table/grouped background color (light gray in light mode)
		self.view.backgroundColor = .systemGroupedBackground
		
			// Reset defaults
		visualEffectView.isHidden = true
		headerIconView.isHidden = true
	//	nameWrapper.isHidden = true
		
		switch mode {
			case .knownSpecies:
				self.title = bird?.name ?? "Species"
			//	nameWrapper.isHidden = true
				headerImageView.contentMode = .scaleAspectFill
					// Header card background
				headerImageView.backgroundColor = .systemBackground // Pure White
			//	startDateLabel?.text = "Start Date"
			//	endDateLabel?.text = "End Date"
				
			case .newSpecies:
				self.title = "Add New Species"
		//		nameWrapper.isHidden = false
				nameTextField.placeholder = "Name"
				setupIconHeader()
		//		startDateLabel?.text = "Start Date"
		//		endDateLabel?.text = "End Date"
				
			case .newWatchlist:
				self.title = "New Watchlist"
		//		nameWrapper.isHidden = false
				nameTextField.placeholder = "Name"
				setupIconHeader()
	//			startDateLabel?.text = "Start Date"
			//	endDateLabel?.text = "Time"
		}
	}
	
	private func setupIconHeader() {
		headerImageView.image = nil
			// Set header card to White (Foreground)
		headerImageView.backgroundColor = .systemBackground
		headerIconView.isHidden = false
		headerIconView.image = UIImage(systemName: "camera.fill")
	}
	
	private func populateData() {
		if let bird = bird, let imageName = bird.images.first {
			headerImageView.image = UIImage(named: imageName) ?? UIImage(systemName: "bird")
		}
	}
	
	@IBAction func didTapLocation(_ sender: Any) {
		print("Location tapped")
	}
}
