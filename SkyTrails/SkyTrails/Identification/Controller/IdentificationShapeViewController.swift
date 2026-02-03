//
//  ShapeViewController.swift
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

    weak var delegate: IdentificationFlowStepDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
      
        if let size = selectedSizeIndex {
            viewModel.updateSize(size)
        }
        
  
        filteredShapes = viewModel.availableShapesForSelectedSize()
        
        shapeCollectionView.delegate = self
        shapeCollectionView.dataSource = self
        
        let nib = UINib(nibName: "shapeCollectionViewCell", bundle: nil)
        shapeCollectionView.register(nib, forCellWithReuseIdentifier: "shapeCell")
        
        setupCollectionViewLayout()
    }

    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        shapeCollectionView.collectionViewLayout = layout
    }



    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredShapes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "shapeCell", for: indexPath) as! shapeCollectionViewCell
        
        let shape = filteredShapes[indexPath.item]
        
        // Use 'icon' as defined in SwiftData BirdShape model
        cell.configure(with: shape.name, imageName: shape.icon)
        
        // Robust ID-based selection check
        if shape.id == viewModel.selectedShape?.id {
            cell.contentView.layer.borderWidth = 3
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.contentView.layer.cornerRadius = 12
            cell.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        }
        
        return cell
    }
    

    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedShape = filteredShapes[indexPath.item]
        
       
        viewModel.selectedShape = selectedShape
        
        collectionView.reloadData()
        
      
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.delegate?.didTapShapes()
        }
    }



    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = collectionView.bounds.width - 40
        let itemWidth = (availableWidth - 12) / 2 // Default 2 columns
        return CGSize(width: itemWidth, height: itemWidth)
    }

    @IBAction func nextTapped(_ sender: UIBarButtonItem) {
        delegate?.didTapShapes()
    }
}

extension IdentificationShapeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
