	//
	//  FieldMarksViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 27/11/25.
	//

import UIKit

class IdentificationFieldMarksViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	
	@IBOutlet weak var tableContainerView: UIView!
	@IBOutlet weak var fieldMarkTableView: UITableView!
	@IBOutlet weak var progressView: UIProgressView!
	
	weak var delegate: IdentificationFlowStepDelegate?
	var selectedFieldMarks: [Int] = [] // Stores indices of selected rows
	
	var viewModel: ViewModel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		styleTableContainer()
		fieldMarkTableView.delegate = self
		fieldMarkTableView.dataSource = self
		setupRightTickButton()
	}
	
	func styleTableContainer() {
		tableContainerView.backgroundColor = .white
		tableContainerView.layer.cornerRadius = 12
		tableContainerView.layer.shadowColor = UIColor.black.cgColor
		tableContainerView.layer.shadowOpacity = 0.1
		tableContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
		tableContainerView.layer.shadowRadius = 8
		tableContainerView.layer.masksToBounds = false
	}
	
		// MARK: - TableView Data Source
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.fieldMarks.count
	}
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	func resize(_ image: UIImage, to size: CGSize) -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { _ in
			image.draw(in: CGRect(origin: .zero, size: size))
		}
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "fieldmark_cell", for: indexPath)
		let item = viewModel.fieldMarks[indexPath.row]
		
		cell.textLabel?.text = item.name
		
		if let img = UIImage(named: item.imageView) {
			let targetSize = CGSize(width: 60, height: 60)
			let resized = resize(img, to: targetSize)
			cell.imageView?.image = resized
			cell.imageView?.contentMode = .scaleAspectFill
			cell.imageView?.frame = CGRect(origin: .zero, size: targetSize)
		} else {
			cell.imageView?.image = nil
		}
		
		let toggle = UISwitch()
		toggle.tag = indexPath.row
		toggle.isOn = selectedFieldMarks.contains(indexPath.row)
		toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
		cell.accessoryView = toggle
		
		return cell
	}
	
	@objc func switchChanged(_ sender: UISwitch) {
		let index = sender.tag
		
		if sender.isOn {
			if selectedFieldMarks.count >= 5 {
				sender.setOn(false, animated: true)
				showMaxLimitAlert()
				return
			}
			if !selectedFieldMarks.contains(index) {
				selectedFieldMarks.append(index)
			}
		} else {
			if let position = selectedFieldMarks.firstIndex(of: index) {
				selectedFieldMarks.remove(at: position)
			}
		}
		print("Selected indices = \(selectedFieldMarks)")
	}
	
	private func showMaxLimitAlert() {
		let alert = UIAlertController(
			title: "Limit Reached",
			message: "You can select at most 5 field marks.",
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
	
	private func setupRightTickButton() {
		let button = UIButton(type: .system)
		button.backgroundColor = .white
		button.layer.cornerRadius = 20
		button.layer.masksToBounds = true
		
		let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
		let image = UIImage(systemName: "checkmark", withConfiguration: config)
		button.setImage(image, for: .normal)
		button.tintColor = .black
		button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
		
		button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
		navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
	}
	
		// MARK: - Navigation Logic
	@objc private func nextTapped() {
			// 1. Get the NAMES of what the user selected (e.g., "Beak", "Eye")
		let selectedNames = selectedFieldMarks.map { viewModel.fieldMarks[$0].name }
		
			// 2. SAVE this list to the Shared Data Model
			// This is the CRITICAL STEP for the next screen
		viewModel.data.fieldMarks = selectedNames
		
			// 3. Perform the initial filter (for the list view later)
		let marksForFilter: [FieldMarkData] = selectedNames.map { name in
			return FieldMarkData(area: name, variant: "", colors: [])
		}
		
		viewModel.filterBirds(
			shape: viewModel.selectedShapeId,
			size: viewModel.selectedSizeCategory,
			location: viewModel.selectedLocation,
			fieldMarks: marksForFilter
		)
		
			// 4. Move to Next Screen
		delegate?.didFinishStep()
	}
}

extension IdentificationFieldMarksViewController: IdentificationProgressUpdatable {
	func updateProgress(current: Int, total: Int) {
		let percent = Float(current) / Float(total)
		progressView.setProgress(percent, animated: true)
	}
}
