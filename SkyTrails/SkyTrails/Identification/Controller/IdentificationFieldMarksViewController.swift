//
//  IdentificationFieldMarksViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class IdentificationFieldMarksViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var CanvasView: UIView!
    @IBOutlet weak var Categories: UICollectionView!
    @IBOutlet weak var progressView: UIProgressView!
    
    weak var delegate: IdentificationFlowStepDelegate?
    var selectedFieldMarks: [Int] = []
    
    var viewModel: IdentificationManager!
    
    // Canvas Layers
    private var baseShapeLayer: UIImageView!
    private var partLayers: [String: UIImageView] = [:]
    
    // Z-Index Order for Bird Parts
    private let layerOrder = [
        "Tail",
        "Leg",
        "Thigh",
        "Head",
        "Neck",
        "Back", "Belly", "Chest",
        "Nape", "Throat", "Crown",
        "Facemask",
        "Beak", "Eye",
        "Wings"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCanvas()
        setupRightTickButton()
    }
    
    // Item 4: Canvas Layout Lifecycle Fix
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let bounds = CanvasView.bounds
        baseShapeLayer?.frame = bounds
        
        for layer in partLayers.values {
            layer.frame = bounds
        }
    }
    
    func setupUI() {
        // Register CategoryCell (Shared with GUIViewController)
        let categoryNib = UINib(nibName: "CategoryCell", bundle: nil)
        Categories.register(categoryNib, forCellWithReuseIdentifier: "CategoryCell")
        
        Categories.delegate = self
        Categories.dataSource = self
        Categories.allowsMultipleSelection = true
        
        if let layout = Categories.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = .zero
        }
    }
    
    /// Sanitizes strings for filenames
    func cleanForFilename(_ name: String) -> String {
        // Special mapping for Finches/Sparrows ID to Asset Prefix
        if name == "Passeridae_Fringillidae" {
            return "finch"
        }
        
        return name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
    
    private func setupCanvas() {
        // Clear existing views
        CanvasView.subviews.forEach { $0.removeFromSuperview() }
        partLayers.removeAll()

        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
        
        // 1. Load the Core Torso (Hollow Base)
        baseShapeLayer = UIImageView(frame: CanvasView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        baseShapeLayer.image = UIImage(named: "id_shape_\(shapeID)_base_core")
        // Item 5: Explicit and Safe Z-Ordering
        baseShapeLayer.layer.zPosition = -1
        CanvasView.addSubview(baseShapeLayer)

        // 2. Loop through and CREATE the layers
        for (index, catName) in layerOrder.enumerated() {
            let imgView = UIImageView(frame: CanvasView.bounds)
            imgView.contentMode = .scaleAspectFit
            
            // Item 5: Explicit and Safe Z-Ordering
            imgView.layer.zPosition = CGFloat(index)
            
            CanvasView.addSubview(imgView)
            partLayers[catName] = imgView
            
            // Initial Load
            updateLayer(category: catName)
        }
    }
    
    func updateLayer(category: String) {
        guard let layer = partLayers[category] else {
            print("IdentificationFieldMarksViewController: Could not find layer for category: \(category)")
            return
        }
        
        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
        let cleanCategory = cleanForFilename(category)
        
        // FUTURE: When colored assets are available, use this naming scheme:
        // Default: "id_canvas_finch_beak_default"
        // Selected: "canvas_Finch_Beak_Default_color"
        //
        // Current behavior: Always load the default asset to prevent empty layers.
        
        let baseName = "id_canvas_\(shapeID)_\(cleanCategory)_default"
        // let targetSuffix = isSelected ? "_color" : "" // Restore this when assets exist
        
        print("IdentificationFieldMarksViewController: Attempting to load image named: \(baseName)")
        
        if let img = UIImage(named: baseName) {
            layer.image = img
            print("IdentificationFieldMarksViewController: Successfully loaded image: \(baseName)")
        } else {
             layer.image = nil
             print("IdentificationFieldMarksViewController: Failed to load image: \(baseName)")
        }
    }
    
    func isCategorySelected(name: String) -> Bool {
        if let index = viewModel.chooseFieldMarks.firstIndex(where: { $0.name == name }) {
            return selectedFieldMarks.contains(index)
        }
        return false
    }
    
    // MARK: - CollectionView DataSource & Delegate
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.chooseFieldMarks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
        let item = viewModel.chooseFieldMarks[indexPath.row]
        
		let isSelected = selectedFieldMarks.contains(indexPath.row)
		if isSelected {
			collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
		}

        cell.configure(name: item.name, iconName: item.imageView, isSelected: isSelected)
        
        return cell
    }
    
    // Item 9: Selection Limit Enforcement (UX Fix)
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if selectedFieldMarks.count >= 5 {
            showMaxLimitAlert()
            return false
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.row
        
        if !selectedFieldMarks.contains(index) {
            selectedFieldMarks.append(index)
        }
        
        // Item 3: Collection View Reload Optimization
  
        
        let categoryName = viewModel.chooseFieldMarks[index].name
        updateLayer(category: categoryName)
        
        print("Selected indices = \(selectedFieldMarks)")
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let index = indexPath.row
        
        if let position = selectedFieldMarks.firstIndex(of: index) {
            selectedFieldMarks.remove(at: position)
        }
        
        // Item 3: Collection View Reload Optimization
        collectionView.reloadItems(at: [indexPath])
        
        let categoryName = viewModel.chooseFieldMarks[index].name
        updateLayer(category: categoryName)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 70, height: 70)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 15
    }
    
    // MARK: - Navigation & Alerts
    
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
    
    private func showMaxLimitAlert() {
        let alert = UIAlertController(
            title: "Limit Reached",
            message: "You can select at most 5 field marks.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func nextTapped() {
        let selectedNames = selectedFieldMarks.map { viewModel.chooseFieldMarks[$0].name }
        viewModel.data.fieldMarks = selectedNames
        
        let marksForFilter: [FieldMarkData] = selectedNames.map { name in
            return FieldMarkData(area: name, variant: "", colors: [])
        }
        
        viewModel.filterBirds(
            shape: viewModel.selectedShapeId,
            size: viewModel.selectedSizeCategory,
            location: viewModel.selectedLocation,
            fieldMarks: marksForFilter
        )
        
        delegate?.didFinishStep()
    }
}

extension IdentificationFieldMarksViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
