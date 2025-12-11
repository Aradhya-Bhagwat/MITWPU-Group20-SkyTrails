	//
	//  GUIViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 09/12/25.
	//

import UIKit

class GUIViewController: UIViewController {
	
		// 1. Add ViewModel reference
	var viewModel: ViewModel!
	weak var delegate: IdentificationFlowStepDelegate?
	
		// You can remove the local 'var data: IdentificationData?' since we use viewModel now
	
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var sizeLabel: UILabel!
	@IBOutlet weak var shapeLabel: UILabel!
	@IBOutlet weak var fieldMarksLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupRightTickButton()
		updateUI()
	}
	
		// 2. Update logic to read from ViewModel
	private func updateUI() {
			// Safety check to ensure viewModel is set
		guard let vm = viewModel else {
			print("❌ Error: ViewModel not set in GUIViewController")
			return
		}
		
		let data = vm.data // Read from the source of truth
		
		dateLabel.text = data.date ?? "-"
		sizeLabel.text = data.size ?? "-"
		shapeLabel.text = data.shape ?? "-"
		
		if let marks = data.fieldMarks, !marks.isEmpty {
			fieldMarksLabel.text = marks.joined(separator: ", ")
		} else {
			fieldMarksLabel.text = "-"
		}
	}
	
	private func setupRightTickButton() {
			// Create button
		let button = UIButton(type: .system)
		
		if #available(iOS 15.0, *) {
			var config = UIButton.Configuration.plain()
			config.baseBackgroundColor = .white
			config.baseForegroundColor = .black
			config.cornerStyle = .capsule
			config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
			
			let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
			let image = UIImage(systemName: "checkmark", withConfiguration: symbolConfig)
			config.image = image
			
			button.configuration = config
			button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
			button.layer.cornerRadius = 20
			button.layer.masksToBounds = true
		} else {
				// Fallback for iOS < 15
			button.backgroundColor = .white
			button.layer.cornerRadius = 20
			button.layer.masksToBounds = true
			
			let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
			let image = UIImage(systemName: "checkmark", withConfiguration: symbolConfig)
			button.setImage(image, for: .normal)
			button.tintColor = .black
		}
		
		button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
		navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
	}
	
	@objc private func nextTapped() {
		delegate?.didFinishStep()
	}
}
