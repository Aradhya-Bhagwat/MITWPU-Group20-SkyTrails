import UIKit
import SwiftData

class GUIViewController: UIViewController {
    
    @IBOutlet weak var variationsCollectionView: UICollectionView!
    @IBOutlet weak var canvasContainerView: UIView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    // Aligned with models: stores the specific field marks selected in the previous step
    private var categories: [BirdFieldMark] = []
    private var currentCategoryIndex: Int = 0

    // Local state for UI tracking (Area Name : Variant Name)
    private var selectedVariations: [String: String] = [:]
    
    private var baseShapeLayer: UIImageView!
    private var partLayers: [String: UIImageView] = [:]
    
    private let layerOrder = [
        "Tail", "Leg", "Thigh", "Head", "Neck", "Back", "Underparts",
        "Nape", "Throat", "Crown", "Facemask", "Beak", "Eye", "Wings"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        let variationNib = UINib(nibName: "VariationCell", bundle: nil)
        variationsCollectionView.register(variationNib, forCellWithReuseIdentifier: "VariationCell")
        let categoryNib = UINib(nibName: "CategoryCell", bundle: nil)
        categoriesCollectionView.register(categoryNib, forCellWithReuseIdentifier: "CategoryCell")
        
        loadData()
        setupCanvas()
        updateNextButtonState()
        
        if !categories.isEmpty {
            selectCategory(at: 0)
        }
    }

    private func updateNextButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !selectedVariations.isEmpty
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = canvasContainerView.bounds
        baseShapeLayer?.frame = bounds
        for layer in partLayers.values {
            layer.frame = bounds
        }
    }
    
    private func loadData() {
        // Aligning with Manager: Get marks based on tempSelectedAreas strings
        guard !viewModel.tempSelectedAreas.isEmpty else {
            self.categories = []
            return
        }
        
        // Filter the marks belonging to the selected shape
        let allMarksForShape = viewModel.selectedShape?.fieldMarks ?? []
        self.categories = allMarksForShape.filter { viewModel.tempSelectedAreas.contains($0.area) }
        
        // Sync already selected variations from the viewModel if they exist
        for mark in categories {
            if let variant = viewModel.selectedFieldMarks[mark.id] {
                selectedVariations[mark.area] = variant.name
            }
        }
    }
    
    private func setupUI() {
        title = "Identify field marks"
        variationsCollectionView.delegate = self
        variationsCollectionView.dataSource = self
        categoriesCollectionView.delegate = self
        categoriesCollectionView.dataSource = self
        variationsCollectionView.backgroundColor = .clear
        categoriesCollectionView.backgroundColor = .clear
        
        if let layout = variationsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.scrollDirection = .horizontal
        }
        if let layout = categoriesCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.scrollDirection = .horizontal
        }
    }

    private func setupCanvas() {
        canvasContainerView.subviews.forEach { $0.removeFromSuperview() }
        partLayers.removeAll()

        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
        let userSelectedAreaNames = categories.map { $0.area }

        baseShapeLayer = UIImageView(frame: canvasContainerView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        baseShapeLayer.image = UIImage(named: "id_shape_\(shapeID)_base_core")
        canvasContainerView.addSubview(baseShapeLayer)

        for catName in layerOrder {
            let imgView = UIImageView(frame: canvasContainerView.bounds)
            imgView.contentMode = .scaleAspectFit
            canvasContainerView.addSubview(imgView)
            partLayers[catName] = imgView

            var imageName: String? = nil
            
            if userSelectedAreaNames.contains(catName) {
                if let selectedVariant = selectedVariations[catName] {
                    imageName = "id_canvas_\(shapeID)_\(cleanForFilename(catName))_\(cleanForFilename(selectedVariant))"
                }
            } else {
                imageName = "id_canvas_\(shapeID)_\(cleanForFilename(catName))_default"
            }
            
            if let name = imageName {
                imgView.image = UIImage(named: name)
            }
        }
    }

    func cleanForFilename(_ name: String) -> String {
        if name == "Passeridae_Fringillidae" { return "finch" }
        return name.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
    }
    
    func selectCategory(at index: Int) {
        guard index < categories.count else { return }
        currentCategoryIndex = index
        let mark = categories[index]
        
        categoryLabel.text = mark.area
        
        variationsCollectionView.reloadData()
        categoriesCollectionView.selectItem(at: IndexPath(item: index, section: 0), animated: true, scrollPosition: .centeredHorizontally)
    }

    func updateCanvas(category: String, variant: String) {
        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
        let imageName = "id_canvas_\(shapeID)_\(cleanForFilename(category))_\(cleanForFilename(variant))"
        
        if let layer = partLayers[category] {
            layer.image = UIImage(named: imageName)
        }
    }

    private func variationThumbnailImage(shapeID: String, categoryName: String, variantName: String) -> UIImage? {
        let cleanCategory = cleanForFilename(categoryName)
        let cleanVariant = cleanForFilename(variantName)
        
        let canvasName = "id_canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
        let baseName = "id_shape_\(shapeID)_base"
        
        if let canvas = UIImage(named: canvasName), let base = UIImage(named: baseName) {
            let renderer = UIGraphicsImageRenderer(size: base.size)
            return renderer.image { _ in
                base.draw(in: CGRect(origin: .zero, size: base.size))
                canvas.draw(in: CGRect(origin: .zero, size: base.size))
            }
        }
        return UIImage(named: "id_icon_\(cleanCategory)_\(cleanVariant)")
    }
    
    func getVariantsForCurrentCategory() -> [FieldMarkVariant] {
        guard currentCategoryIndex < categories.count else { return [] }
        // Accessing the relationship from BirdFieldMark model
        return categories[currentCategoryIndex].variants ?? []
    }
    
    @IBAction func nextTapped(_ sender: Any) {
        guard !selectedVariations.isEmpty else { return }
        // The viewModel.filterBirds logic remains unchanged as requested,
        // we just ensure the manager's internal filter is triggered.
        delegate?.didFinishStep()
    }
}

extension GUIViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionView == categoriesCollectionView ? categories.count : getVariantsForCurrentCategory().count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
            let mark = categories[indexPath.row]
            let isSelected = indexPath.row == currentCategoryIndex
            cell.configure(name: mark.area, iconName: mark.iconName, isSelected: isSelected)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VariationCell", for: indexPath) as! VariationCell
            let variant = getVariantsForCurrentCategory()[indexPath.row]
            let categoryName = categories[currentCategoryIndex].area
            
            let isSelected = selectedVariations[categoryName] == variant.name
            let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
            let thumb = variationThumbnailImage(shapeID: shapeID, categoryName: categoryName, variantName: variant.name)
            cell.configure(image: thumb, isSelected: isSelected)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoriesCollectionView {
            selectCategory(at: indexPath.row)
        } else {
            let variant = getVariantsForCurrentCategory()[indexPath.row]
            let currentMark = categories[currentCategoryIndex]
            
            selectedVariations[currentMark.area] = variant.name
            
            // Aligning with IdentificationManager.swift: call toggleVariant to update model state
            viewModel.toggleVariant(variant, for: currentMark)
            
            variationsCollectionView.reloadData()
            updateCanvas(category: currentMark.area, variant: variant.name)
            updateNextButtonState()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView == categoriesCollectionView ? CGSize(width: 70, height: 70) : CGSize(width: 60, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 15
    }
}
