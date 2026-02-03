import UIKit
import SwiftData

class GUIViewController: UIViewController {
    
    @IBOutlet weak var variationsCollectionView: UICollectionView!
    @IBOutlet weak var canvasContainerView: UIView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    // Data source derived from the selected shape
    private var categories: [BirdFieldMark] = []
    private var currentCategoryIndex: Int = 0

    // Layers for the visual bird builder
    private var baseShapeLayer: UIImageView!
    private var partLayers: [String: UIImageView] = [:]
    
    // The specific order in which layers are stacked (bottom to top)
    private let layerOrder = [
        "Tail", "Leg", "Thigh", "Head", "Neck",
        "Back", "Underparts", "Nape", "Throat", "Crown",
        "Facemask", "Beak", "Eye", "Wings"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerCells()
        loadData()
        setupCanvas()
        
        if !categories.isEmpty {
            selectCategory(at: 0)
        }
    }
    
    /// CRITICAL: This ensures the bird layers are centered and sized correctly
    /// after the AutoLayout engine determines the container's final size.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = canvasContainerView.bounds
        baseShapeLayer?.frame = bounds
        for layer in partLayers.values {
            layer.frame = bounds
        }
    }
    
    private func registerCells() {
        let variationNib = UINib(nibName: "VariationCell", bundle: nil)
        variationsCollectionView.register(variationNib, forCellWithReuseIdentifier: "VariationCell")
        let categoryNib = UINib(nibName: "CategoryCell", bundle: nil)
        categoriesCollectionView.register(categoryNib, forCellWithReuseIdentifier: "CategoryCell")
    }
    
    private func loadData() {
        // Fetch field marks directly from the selected shape in the VM
        guard let shape = viewModel.selectedShape else {
            self.categories = []
            return
        }
        
        // Sort by layerOrder so the horizontal list matches the visual stacking logic
        let fieldMarks = shape.fieldMarks ?? []
        self.categories = fieldMarks.sorted { mark1, mark2 in
            let index1 = layerOrder.firstIndex(of: mark1.area) ?? 999
            let index2 = layerOrder.firstIndex(of: mark2.area) ?? 999
            return index1 < index2
        }
        
        if categories.isEmpty {
            print("DEBUG: No field marks found for shape: \(shape.name). Check your Seeder.")
        }
    }
    
    private func setupUI() {
        title = "Identify field marks"
        variationsCollectionView.delegate = self
        variationsCollectionView.dataSource = self
        categoriesCollectionView.delegate = self
        categoriesCollectionView.dataSource = self
        
        // Ensure flow layouts are horizontal and items don't resize unexpectedly
        if let layout = variationsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = .zero
        }
        if let layout = categoriesCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = .zero
        }
    }

    private func setupCanvas() {
        // Clear existing layers if re-initializing
        canvasContainerView.subviews.forEach { $0.removeFromSuperview() }
        partLayers.removeAll()

        let shapeID = cleanForFilename(viewModel.selectedShape?.id ?? "finch")

        // 1. Create Base Layer
        baseShapeLayer = UIImageView(frame: canvasContainerView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        let baseName = "id_shape_\(shapeID)_base_core"
        if let img = UIImage(named: baseName) {
            baseShapeLayer.image = img
        }
        canvasContainerView.addSubview(baseShapeLayer)

        // 2. Create Part Layers (Ordered by layerOrder - unchanged)
        for catName in layerOrder {
            let imgView = UIImageView(frame: canvasContainerView.bounds)
            imgView.contentMode = .scaleAspectFit
            canvasContainerView.addSubview(imgView)
            partLayers[catName] = imgView

            // Find if there's a user selection for this category
            let category = categories.first(where: { $0.area == catName })
            let activeVariant = viewModel.selectedFieldMarks[category?.id ?? UUID()]
            
            // If no selection, we show the "default" asset for that body part
            let variantName = activeVariant?.name ?? "default"
            let imageName = "id_canvas_\(shapeID)_\(cleanForFilename(catName))_\(cleanForFilename(variantName))"
            
            imgView.image = UIImage(named: imageName)
        }
    }

    func cleanForFilename(_ name: String) -> String {
        // Special case for your specific family naming in JSON
        if name == "Passeridae_Fringillidae" { return "finch" }
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
    
    func selectCategory(at index: Int) {
        guard index < categories.count else { return }
        currentCategoryIndex = index
        categoryLabel.text = categories[index].area
        
        variationsCollectionView.reloadData()
        categoriesCollectionView.reloadData()
        
        let indexPath = IndexPath(item: index, section: 0)
        categoriesCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
    }

    func updateCanvas(categoryName: String, variantName: String) {
        let shapeID = cleanForFilename(viewModel.selectedShape?.id ?? "finch")
        let imageName = "id_canvas_\(shapeID)_\(cleanForFilename(categoryName))_\(cleanForFilename(variantName))"
        
        if let layer = partLayers[categoryName] {
            // Animating the transition makes the "builder" feel high quality
            UIView.transition(with: layer, duration: 0.2, options: .transitionCrossDissolve, animations: {
                layer.image = UIImage(named: imageName)
            }, completion: nil)
        }
    }

    @IBAction func nextTapped(_ sender: Any) {
        // The viewModel already has the selectedFieldMarks synced
        viewModel.runFilter()
        delegate?.didFinishStep()
    }
}

// MARK: - CollectionView Logic
extension GUIViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoriesCollectionView {
            return categories.count
        } else {
            guard !categories.isEmpty, currentCategoryIndex < categories.count else { return 0 }
            return categories[currentCategoryIndex].variants?.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
            let item = categories[indexPath.row]
            
            // Build the icon name based on category area (e.g., id_icn_beak)
            let iconName = "id_icn_\(cleanForFilename(item.area))"
            cell.configure(name: item.area, iconName: iconName, isSelected: indexPath.row == currentCategoryIndex)
            return cell
            
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VariationCell", for: indexPath) as! VariationCell
            let currentMark = categories[currentCategoryIndex]
            
            guard let variants = currentMark.variants, indexPath.row < variants.count else { return cell }
            
            let variant = variants[indexPath.row]
            let isSelected = viewModel.selectedFieldMarks[currentMark.id] == variant
            let shapeID = cleanForFilename(viewModel.selectedShape?.id ?? "finch")
            
            // Generate the thumbnail by compositing the bird base with this specific variant
            let thumb = variationThumbnailImage(shapeID: shapeID, categoryName: currentMark.area, variantName: variant.name)
            
            cell.configure(image: thumb, isSelected: isSelected)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoriesCollectionView {
            selectCategory(at: indexPath.row)
        } else {
            let currentMark = categories[currentCategoryIndex]
            guard let variants = currentMark.variants else { return }
            let variant = variants[indexPath.row]
            
            // Update state in ViewModel
            viewModel.toggleVariant(variant, for: currentMark)
            
            // UI Feedback
            variationsCollectionView.reloadData()
            updateCanvas(categoryName: currentMark.area, variantName: variant.name)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView == categoriesCollectionView ? CGSize(width: 70, height: 70) : CGSize(width: 60, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 15
    }
}

// MARK: - Image Composition Helper
extension GUIViewController {
    private func variationThumbnailImage(shapeID: String, categoryName: String, variantName: String) -> UIImage? {
        let cleanCategory = cleanForFilename(categoryName)
        let cleanVariant = cleanForFilename(variantName)
        
        let canvasName = "id_canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
        let baseName = "id_shape_\(shapeID)_base" // Note: Thumbnails use the generic base, not the 'core'
        
        if let canvas = UIImage(named: canvasName), let base = UIImage(named: baseName) {
            let renderer = UIGraphicsImageRenderer(size: base.size)
            return renderer.image { _ in
                base.draw(in: CGRect(origin: .zero, size: base.size))
                canvas.draw(in: CGRect(origin: .zero, size: base.size))
            }
        }
        // Fallback to a dedicated icon if compositing fails
        return UIImage(named: "id_icon_\(cleanCategory)_\(cleanVariant)")
    }
}
