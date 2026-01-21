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

        let itemsPerRow: CGFloat =
            UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2

        let totalSpacing =
            layout.sectionInset.left +
            layout.sectionInset.right +
            layout.minimumInteritemSpacing * (itemsPerRow - 1)

        let width =
            (collectionView.bounds.width - totalSpacing) / itemsPerRow

        return CGSize(width: width, height: 180)
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
