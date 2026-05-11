import UIKit

class IdentificationShapeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var shapeCollectionView: UICollectionView!
    @IBOutlet weak var progressView: UIProgressView!

    var viewModel: IdentificationManager!
    var selectedSizeIndex: Int?
    var filteredShapes: [BirdShape] = []
    var selectedShapeId: String?

    weak var delegate: IdentificationFlowStepDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Select Shape"
        self.tabBarItem.title = "Identification"
        
        viewModel.fetchShapes()
        let sizeFilteredShapes = viewModel.availableShapesForSelectedSize()
        
        // Filter: only keep shapes that have field marks with variants (and thus have area data)
        filteredShapes = sizeFilteredShapes.filter { shape in
            guard let fieldMarks = shape.fieldMarks, !fieldMarks.isEmpty else { return false }
            return fieldMarks.contains { fieldMark in
                guard let variants = fieldMark.variants else { return false }
                return !variants.isEmpty
            }
        }
        
        selectedShapeId = viewModel.selectedShapeId
        
        setupCollectionView()
        setupCollectionViewLayout()
        updateNextButtonState()
        shapeCollectionView.reloadData()
    }

    private func updateNextButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = (selectedShapeId != nil)
    }
    
    private func setupCollectionView() {
        shapeCollectionView.delegate = self
        shapeCollectionView.dataSource = self
        let nib = UINib(nibName: "shapeCollectionViewCell", bundle: nil)
        shapeCollectionView.register(nib, forCellWithReuseIdentifier: "shapeCell")
    }

    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        shapeCollectionView.collectionViewLayout = layout
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }

        let minItemWidth: CGFloat = 120
        let maxItemsPerRow: CGFloat = 4
        let availableWidth = collectionView.bounds.width
            - layout.sectionInset.left
            - layout.sectionInset.right
        
        var itemsPerRow: CGFloat = 1
        while true {
            let potentialWidth = (availableWidth - (layout.minimumInteritemSpacing * (itemsPerRow - 1))) / itemsPerRow
            if potentialWidth >= minItemWidth && itemsPerRow < maxItemsPerRow {
                itemsPerRow += 1
            } else {
                if potentialWidth < minItemWidth && itemsPerRow > 1 { itemsPerRow -= 1 }
                break
            }
        }
        
        let itemWidth = (availableWidth - (layout.minimumInteritemSpacing * (itemsPerRow - 1))) / itemsPerRow
        return CGSize(width: itemWidth, height: itemWidth)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredShapes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "shapeCell", for: indexPath) as! shapeCollectionViewCell
        
        let shape = filteredShapes[indexPath.item]
        cell.configure(with: shape.name, imageName: shape.icon)
        let isSelected = (shape.bird_shape_id == selectedShapeId)
        updateCellUI(cell, isSelected: isSelected)
        
        return cell
    }
    
    private func updateCellUI(_ cell: UICollectionViewCell, isSelected: Bool) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let unselectedColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        let selectedColor: UIColor = UIColor.systemBlue.withAlphaComponent(isDarkMode ? 0.24 : 0.10)
        let unselectedBorderColor: UIColor = isDarkMode ? .systemGray3 : .systemGray4

        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = false
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
        
        if isSelected {
            cell.contentView.layer.borderWidth = 3
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.contentView.backgroundColor = selectedColor
        } else {
            cell.contentView.layer.borderWidth = 1
            cell.contentView.layer.borderColor = unselectedBorderColor.cgColor
            cell.contentView.backgroundColor = unselectedColor
        }

        if isDarkMode {
            cell.layer.shadowOpacity = 0
            cell.layer.shadowRadius = 0
            cell.layer.shadowOffset = .zero
            cell.layer.shadowPath = nil
        } else {
            cell.layer.shadowColor = UIColor.black.cgColor
            cell.layer.shadowOpacity = 0.08
            cell.layer.shadowOffset = CGSize(width: 0, height: 3)
            cell.layer.shadowRadius = 6
            cell.layer.shadowPath = UIBezierPath(
                roundedRect: cell.bounds,
                cornerRadius: cell.layer.cornerRadius
            ).cgPath
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedShape = filteredShapes[indexPath.item]
        viewModel.selectedShape = selectedShape
        self.selectedShapeId = selectedShape.bird_shape_id
        updateNextButtonState()
        
        collectionView.reloadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.delegate?.didTapShapes()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.shapeCollectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    @IBAction func nextTapped(_ sender: UIBarButtonItem) {
        guard selectedShapeId != nil else { return }
        delegate?.didTapShapes()
    }
}

extension IdentificationShapeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
