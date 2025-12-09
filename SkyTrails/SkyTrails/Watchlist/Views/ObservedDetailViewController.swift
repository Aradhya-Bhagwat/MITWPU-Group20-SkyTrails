	//
	//  ObservedDetailViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 09/12/25.
	//

import UIKit

class ObservedDetailViewController: UIViewController {
	
		// MARK: - Data Dependency
	var bird: Bird? // nil if adding new
	weak var coordinator: WatchlistCoordinator?
	
	private var selectedImageName: String?
	
		// MARK: - IBOutlets
	@IBOutlet weak var birdImageView: UIImageView!
	@IBOutlet weak var dateLabel: UILabel!

	@IBOutlet weak var dateTimePicker: UIDatePicker!
// Note: In your XML this view might not exist in Observed, but we'll keep the outlet if it's there.
	@IBOutlet weak var notesTextView: UITextView!
	@IBOutlet weak var searchTextField: UITextField! // This is actually the Name TextField in Observed View
	@IBOutlet weak var detailsCardView: UIView!

	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupStyling()
		setupInteractions()
		
			// Load data if editing existing (not applicable for "Add New", but good practice)
		if let birdData = bird {
			configure(with: birdData)
		} else {
				// New Entry Setup
			self.navigationItem.title = "New Observation"
			birdImageView.image = UIImage(systemName: "camera.fill")
			birdImageView.tintColor = .systemGray
		}
		
			// Save Button
		let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
		navigationItem.rightBarButtonItem = saveButton
	}
	
	private func setupInteractions() {
			// Image Tap Gesture
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapImage))
		birdImageView.isUserInteractionEnabled = true
		birdImageView.addGestureRecognizer(tapGesture)
	}
	
	@objc func didTapImage() {
		let picker = UIImagePickerController()
		picker.sourceType = .photoLibrary // Or .camera
		picker.delegate = self
		picker.allowsEditing = true
		present(picker, animated: true)
	}
	
	@objc func didTapSave() {
		guard let name = searchTextField.text, !name.isEmpty else {
			let alert = UIAlertController(title: "Missing Info", message: "Please enter a bird name.", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default))
			present(alert, animated: true)
			return
		}
		
			// 1. Create Image Array (use selected image or default)
		var images: [String] = []
		if let imgName = selectedImageName {
			images.append(imgName)
		} else {
			images.append("bird_placeholder") // Ensure you have a placeholder asset or handle nil
		}
		
			// 2. Create Location Array
			// Note: Using a text field for location in this context based on your XML structure
			// In the Observed XML, there is a location text field near the bottom,
			// but let's assume 'location' is handled or default it for now.
		let loc = "User Location" // Or fetch from the second text field if you wire it up
		
			// 3. Create the New Bird Object
		let newBird = Bird(
			name: name,
			scientificName: "Unknown", // Default
			images: images,
			rarity: [.common], // Default
			location: [loc],
			date: [dateTimePicker.date],
			observedBy: ["person.circle.fill"] // Current user
		)
		
			// 4. Pass back to Coordinator
		coordinator?.saveBirdDetails(bird: newBird)
	}
	
		// MARK: - Configuration
	func configure(with bird: Bird) {
		searchTextField.text = bird.name
		if let imageName = bird.images.first {
			birdImageView.image = UIImage(named: imageName)
		}
		if let date = bird.date.first {
			dateTimePicker.date = date
		}
	}
	
		// MARK: - Styling
	func setupStyling() {
		view.backgroundColor = .systemGray6
		birdImageView.layer.cornerRadius = 24
		birdImageView.clipsToBounds = true
		birdImageView.contentMode = .scaleAspectFill
		
		searchTextField.layer.cornerRadius = 8
		searchTextField.layer.masksToBounds = true
		
		styleCard(detailsCardView)
			// Check if locationCardView is connected before styling
		
	}
	
	func styleCard(_ view: UIView) {
		view.layer.cornerRadius = 20
		view.backgroundColor = .white
		view.layer.shadowColor = UIColor.black.cgColor
		view.layer.shadowOpacity = 0.08
		view.layer.shadowOffset = CGSize(width: 0, height: 4)
		view.layer.shadowRadius = 12
		view.layer.masksToBounds = false
	}
}

// MARK: - Image Picker Delegate
extension ObservedDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		picker.dismiss(animated: true)
		
		guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else { return }
		
			// 1. Update UI
		birdImageView.image = image
		
			// 2. Save to Disk and get filename
		if let filename = saveImageToDocuments(image) {
			self.selectedImageName = filename
		}
	}
	
	private func saveImageToDocuments(_ image: UIImage) -> String? {
		guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
		let filename = UUID().uuidString + ".jpg"
		let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
		
		do {
			try data.write(to: fileURL)
			return filename // This string matches the `Bird` model `images` array expectation
		} catch {
			print("Error saving image: \(error)")
			return nil
		}
	}
	
	private func getDocumentsDirectory() -> URL {
		return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}
}
