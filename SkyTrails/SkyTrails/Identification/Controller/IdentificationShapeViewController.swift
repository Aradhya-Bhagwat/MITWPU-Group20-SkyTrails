//
//  ShapeViewController.swift
//  SkyTrails
//
//  Created by Disha Jain on 27/11/25.
//

//
//  IdentificationShapeViewController.swift
//  SkyTrails
//
//  Created by Disha Jain on 27/11/25.
//

import UIKit

class IdentificationShapeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var shapeCollectionView: UICollectionView!
    @IBOutlet weak var progressView: UIProgressView!

    var viewModel: IdentificationManager!
    var selectedSizeIndex: Int?
    var filteredShapes: [BirdShape] = []
    var selectedShapeIndex: Int?

    weak var delegate: IdentificationFlowStepDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        styleTableContainer()

        

        viewModel.selectedSizeCategory = selectedSizeIndex
        filteredShapes = viewModel.availableShapesForSelectedSize()
        

        shapeCollectionView.delegate = self
        shapeCollectionView.dataSource = self
        

        let nib = UINib(nibName: "shapeCollectionViewCell", bundle: nil)
        shapeCollectionView.register(nib, forCellWithReuseIdentifier: "shapeCell")
        
        setupCollectionViewLayout()
        setupRightTickButton()
        
  
        if let shapeId = viewModel.selectedShapeId,
           let index = filteredShapes.firstIndex(where: { $0.id == shapeId }) {
            selectedShapeIndex = index
        }
    }
    
    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        
        let itemWidth = (shapeCollectionView.bounds.width - 36) / 2

        
        layout.itemSize = CGSize(width: itemWidth, height: 180)
        
        shapeCollectionView.collectionViewLayout = layout
    }

    func styleTableContainer() {
        tableContainerView.layer.cornerRadius = 12
        tableContainerView.layer.shadowColor = UIColor.black.cgColor
        tableContainerView.layer.shadowOpacity = 0.1
        tableContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        tableContainerView.layer.shadowRadius = 8
        tableContainerView.layer.masksToBounds = false
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredShapes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "shapeCell", for: indexPath) as! shapeCollectionViewCell
        
        let shape = filteredShapes[indexPath.item]
        cell.configure(with: shape.name, imageName: shape.imageView)
        
        
        if selectedShapeIndex == indexPath.item {
            cell.contentView.layer.borderWidth = 3
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.contentView.layer.cornerRadius = 12
            cell.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } else {
            cell.contentView.layer.borderWidth = 1
            cell.contentView.layer.borderColor = UIColor.systemGray4.cgColor
            cell.contentView.layer.cornerRadius = 12
            cell.contentView.backgroundColor = .white
        }
        
        return cell
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedShape = filteredShapes[indexPath.item]
        
     
        selectedShapeIndex = indexPath.item
        
   
        viewModel.selectedShapeId = selectedShape.id
        viewModel.data.shape = selectedShape.name
        
      
        viewModel.filterBirds(
            shape: selectedShape.id,
            size: viewModel.selectedSizeCategory,
            location: viewModel.selectedLocation,
            fieldMarks: [] // Field marks not selected yet
        )
        
       
        collectionView.reloadData()
        
      
        delegate?.didTapShapes()
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
        delegate?.didTapShapes()
    }
}

extension IdentificationShapeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
