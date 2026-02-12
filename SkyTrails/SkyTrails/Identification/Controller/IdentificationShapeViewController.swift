import UIKit

class IdentificationShapeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var shapeCollectionView: UICollectionView!
    @IBOutlet weak var progressView: UIProgressView!

    var viewModel: IdentificationManager!
    var selectedSizeIndex: Int?
    var filteredShapes: [BirdShape] = []
    
    // Local state to track selection
    var selectedShapeId: String?

    weak var delegate: IdentificationFlowStepDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // filteredShapes will reflect the current selected size from the viewModel
        filteredShapes = viewModel.availableShapesForSelectedSize()
        selectedShapeId = viewModel.selectedShapeId
        
        setupCollectionView()
        setupCollectionViewLayout()
        updateNextButtonState()
    }

    private func updateNextButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = (selectedShapeId != nil)
    }
    
    private func setupCollectionView() {
        shapeCollectionView.delegate = self
        shapeCollectionView.dataSource = self
        
        // Match the class name 'shapeCollectionViewCell' from your original code
        let nib = UINib(nibName: "shapeCollectionViewCell", bundle: nil)
        shapeCollectionView.register(nib, forCellWithReuseIdentifier: "shapeCell")
    }

    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        shapeCollectionView.collectionViewLayout = layout
    }

    // MARK: - CollectionView Logic (Original Logic Preserved)
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }

        let minItemWidth: CGFloat = 100
        let maxItemsPerRow: CGFloat = 4
        let interItemSpacing = layout.minimumInteritemSpacing
        let sectionInsets = layout.sectionInset.left + layout.sectionInset.right
        let availableWidth = collectionView.bounds.width - sectionInsets

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
        }
    
        itemsPerRow = max(1, min(itemsPerRow, maxItemsPerRow))
        let actualTotalSpacing = interItemSpacing * (itemsPerRow - 1)
        let itemWidth = (availableWidth - actualTotalSpacing) / itemsPerRow
        return CGSize(width: itemWidth, height: itemWidth)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredShapes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "shapeCell", for: indexPath) as! shapeCollectionViewCell
        
        let shape = filteredShapes[indexPath.item]
        
        // Using 'icon' as per your model/seeder
        cell.configure(with: shape.name, imageName: shape.icon)
        
        // Compare against local selectedShapeId
        let isSelected = (shape.id == selectedShapeId)
        updateCellUI(cell, isSelected: isSelected)
        
        return cell
    }
    
    private func updateCellUI(_ cell: UICollectionViewCell, isSelected: Bool) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let unselectedColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = false
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
        
        if isSelected {
            if isDarkMode {
                cell.contentView.layer.borderWidth = 0
                cell.contentView.layer.borderColor = UIColor.clear.cgColor
                cell.contentView.backgroundColor = .secondarySystemBackground
            } else {
                cell.contentView.layer.borderWidth = 3
                cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                cell.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            }
        } else {
            cell.contentView.layer.borderWidth = isDarkMode ? 0 : 1
            cell.contentView.layer.borderColor = isDarkMode ? UIColor.clear.cgColor : UIColor.systemGray4.cgColor
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
        
        // 1. Sync the actual object to the ViewModel
        viewModel.selectedShape = selectedShape
        
        // 2. Update local UI state
        self.selectedShapeId = selectedShape.id
        updateNextButtonState()
        
        collectionView.reloadData()
        
        // 3. Proceed to next step
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
