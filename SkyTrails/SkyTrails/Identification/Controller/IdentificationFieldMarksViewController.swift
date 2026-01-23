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
    
 
    private var baseShapeLayer: UIImageView!
    private var partLayers: [String: UIImageView] = [:]
    

    private let layerOrder = [
        "Tail",
        "Leg",
        "Thigh",
        "Head",
        "Neck",
        "Back", "Underparts",
        "Nape", "Throat", "Crown",
        "Facemask",
        "Beak", "Eye",
        "Wings"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCanvas()
       
    }
    
   
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let bounds = CanvasView.bounds
        baseShapeLayer?.frame = bounds
        
        for layer in partLayers.values {
            layer.frame = bounds
        }
    }
    
    func setupUI() {
        
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
    
    
    func cleanForFilename(_ name: String) -> String {
        
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
        
        
        baseShapeLayer = UIImageView(frame: CanvasView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        baseShapeLayer.image = UIImage(named: "id_shape_\(shapeID)_base_core")
       
        baseShapeLayer.layer.zPosition = -1
        CanvasView.addSubview(baseShapeLayer)

       
        for (index, catName) in layerOrder.enumerated() {
            let imgView = UIImageView(frame: CanvasView.bounds)
            imgView.contentMode = .scaleAspectFit
            
            
            imgView.layer.zPosition = CGFloat(index)
            
            CanvasView.addSubview(imgView)
            partLayers[catName] = imgView
            
           
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
        
        let isSelected = isCategorySelected(name: category)
        
        let baseName: String
        if isSelected {
            baseName = "canvas_\(shapeID)_\(cleanCategory)_color"
        } else {
            baseName = "id_canvas_\(shapeID)_\(cleanCategory)_default"
        }
        
        print("IdentificationFieldMarksViewController: Attempting to load image named: \(baseName) (selected: \(isSelected))")
        
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
        
      
  
        
        let categoryName = viewModel.chooseFieldMarks[index].name
        updateLayer(category: categoryName)
        
        print("Selected indices = \(selectedFieldMarks)")
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let index = indexPath.row
        
        if let position = selectedFieldMarks.firstIndex(of: index) {
            selectedFieldMarks.remove(at: position)
        }
        
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
    

    
    private func showMaxLimitAlert() {
        let alert = UIAlertController(
            title: "Limit Reached",
            message: "You can select at most 5 field marks.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func nextTapped(_ sender: Any) {
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
