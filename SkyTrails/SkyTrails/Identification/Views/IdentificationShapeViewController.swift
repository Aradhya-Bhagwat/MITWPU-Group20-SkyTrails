//
//  ShapeViewController.swift
//  SkyTrails
//
//  Created by Disha Jain on 27/11/25.
//

import UIKit

class IdentificationShapeViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    

    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var shapeTableView: UITableView!
    
    @IBOutlet weak var progressView: UIProgressView!

    var viewModel: IdentificationModels!
    var selectedSizeIndex: Int?
    var filteredShapes: [BirdShape] = []

    weak var delegate: IdentificationFlowStepDelegate?

    func styleTableContainer() {
        tableContainerView.layer.cornerRadius = 12
        tableContainerView.layer.shadowColor = UIColor.black.cgColor
        tableContainerView.layer.shadowOpacity = 0.1
        tableContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        tableContainerView.layer.shadowRadius = 8
        tableContainerView.layer.masksToBounds = false
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredShapes.count
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedShape = filteredShapes[indexPath.row]
        
        // Update ViewModel state
        viewModel.selectedShapeId = selectedShape.id

			// Inside tableView didSelectRowAt
		viewModel.data.shape = selectedShape.name // Needed for Summary
		viewModel.selectedShapeId = selectedShape.id // Needed for Filtering
		
        // Trigger intermediate filtering
        viewModel.filterBirds(
            shape: selectedShape.id,
            size: viewModel.selectedSizeCategory,
            location: viewModel.selectedLocation,
            fieldMarks: [] // Field marks not selected yet
        )
        
        delegate?.didTapShapes()

    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "shape_cell", for: indexPath)
        let item = filteredShapes[indexPath.row]
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
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        styleTableContainer()
        applySizeFilter()
        shapeTableView.delegate = self
        shapeTableView.dataSource = self
        setupRightTickButton()
        
    }
    
    private func setupRightTickButton() {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "checkmark", withConfiguration: config), for: .normal)
        button.tintColor = .black
        
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

    @objc private func nextTapped() {
        // If a shape is selected in the table, we proceed.
        // Even if nothing is explicitly selected (user just wants to skip or current selection is implied),
        // we trigger the delegate to move forward.
        delegate?.didTapShapes()
		
    }
   
    func applySizeFilter() {
        // New database shapes don't currently have size categories mapped in the struct.
        // Showing all shapes to prevent empty screen.
        // Future improvement: derive valid shapes from birds that match the selected size.
        filteredShapes = viewModel.birdShapes
    }

  

   

}
extension IdentificationShapeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
