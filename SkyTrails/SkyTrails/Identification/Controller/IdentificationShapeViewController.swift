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
        

        viewModel.selectedSizeCategory = selectedSizeIndex
        filteredShapes = viewModel.availableShapesForSelectedSize()
        

        shapeCollectionView.delegate = self
        shapeCollectionView.dataSource = self
        

        let nib = UINib(nibName: "shapeCollectionViewCell", bundle: nil)
        shapeCollectionView.register(nib, forCellWithReuseIdentifier: "shapeCell")
        
        setupCollectionViewLayout()
      
        
  
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

        shapeCollectionView.collectionViewLayout = layout
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {

        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }

        let minItemWidth: CGFloat = 100 // Define minimum desirable width for a card
        let maxItemsPerRow: CGFloat = 4 // User requested maximum 4 cards per row
        let interItemSpacing = layout.minimumInteritemSpacing
        let sectionLeftInset = layout.sectionInset.left
        let sectionRightInset = layout.sectionInset.right

        let availableWidth = collectionView.bounds.width - sectionLeftInset - sectionRightInset

        var itemsPerRow: CGFloat = 1
      
        while true {
            let potentialTotalSpacing = interItemSpacing * (itemsPerRow - 1)
            let potentialWidth = (availableWidth - potentialTotalSpacing) / itemsPerRow

            if potentialWidth >= minItemWidth {
                itemsPerRow += 1
            } else {
                itemsPerRow -= 1
                break
            }
        
            if itemsPerRow == 0 {
                itemsPerRow = 1
                break
            }
        }
    
        if itemsPerRow < 1 { itemsPerRow = 1 }

        if itemsPerRow > maxItemsPerRow { itemsPerRow = maxItemsPerRow }

        let actualTotalSpacing = interItemSpacing * (itemsPerRow - 1)
        let itemWidth = (availableWidth - actualTotalSpacing) / itemsPerRow
        
       
        let itemHeight = itemWidth * 1.0

        return CGSize(width: itemWidth, height: itemHeight)
    }

    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredShapes.count
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.shapeCollectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
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
            fieldMarks: [] 
        )
        collectionView.reloadData()
        delegate?.didTapShapes()
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
