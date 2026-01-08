import UIKit

class GUIViewController: UIViewController {
	
		
	@IBOutlet weak var variationsCollectionView: UICollectionView!
	@IBOutlet weak var canvasContainerView: UIView!
	@IBOutlet weak var categoryLabel: UILabel!
	@IBOutlet weak var categoriesCollectionView: UICollectionView!
	
		
	var viewModel: IdentificationModels!
	weak var delegate: IdentificationFlowStepDelegate?
	
		// Data Sources
	private var categories: [ChooseFieldMark] = []
	private var currentCategoryIndex: Int = 0
	
		// State
	private var selectedVariations: [String: String] = [:]
	
		// Canvas Layers
	private var baseShapeLayer: UIImageView!
	private var partLayers: [String: UIImageView] = [:]
	
		// Z-Index Order (Bottom to Top)
		// Adjust this based on your specific bird art (e.g., Wings usually go on top of Body)
	private let layerOrder = [
		"Tail", "Leg", "Thigh",         // Background parts
		"Back", "Belly","Chest",
        "Nape","Throat", "Crown",              // Head base
		"Beak", "Eye",                  // Face details
		"Wings"                         // Foreground
	]
	
		
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		
		let variationNib = UINib(nibName: "VariationCell", bundle: nil)
		variationsCollectionView.register(variationNib, forCellWithReuseIdentifier: "VariationCell")
		let categoryNib = UINib(nibName: "CategoryCell", bundle: nil)
		categoriesCollectionView.register(categoryNib, forCellWithReuseIdentifier: "CategoryCell")
		
		loadData()
		setupCanvas() // Call setupCanvas AFTER loadData
		setupRightTickButton()
		
		if !categories.isEmpty {
			selectCategory(at: 0)
		}
	}
	
		
	private func loadData() {
			// 1. Get the names you selected (e.g. "Beak", "Eye")
		guard let selectedNames = viewModel.data.fieldMarks, !selectedNames.isEmpty else {
			print("⚠️ No user selection found.")
			self.categories = []
			return
		}
		
			// 2. Use 'fieldMarks' (The list of Body Parts)
        let allParts = viewModel.chooseFieldMarks
		
			// 3. Filter to get the objects for the selected names
		self.categories = allParts.filter { part in
			return selectedNames.contains(part.name)
		}
		
		print("✅ GUI Loaded: \(self.categories.map { $0.name })")
	}
	
	private func setupUI() {
		title = "Identify field marks"
		variationsCollectionView.delegate = self
		variationsCollectionView.dataSource = self
		categoriesCollectionView.delegate = self
		categoriesCollectionView.dataSource = self
		
			// --- FIX IS HERE ---
			// We must disable estimatedItemSize so the delegate 'sizeForItemAt' is respected.
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
            // Clear any existing subviews if reloading
            canvasContainerView.subviews.forEach { $0.removeFromSuperview() }
            partLayers.removeAll()
            
            // 1. Determine Base Suffix based on selection
            // Logic: If a part is selected, we load a base that is MISSING that part
            // so the user can overlay their choice.
            
            let hasTail = categories.contains { $0.name == "Tail" }
            let hasLeg  = categories.contains { $0.name == "Leg" }
            
            let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
            var baseSuffix = "base" // Default: Both are NOT selected
            
            if hasTail && hasLeg {
                // Both selected -> "base_no_leg_tail"
                baseSuffix = "base_no_leg_tail"
            } else if hasTail {
                // Tail only -> "base_no_tail"
                baseSuffix = "base_no_tail"
            } else if hasLeg {
                // Leg only -> "base_no_leg"
                baseSuffix = "base_no_leg"
            }
            
            let baseImageName = "shape_\(shapeID)_\(baseSuffix)"
            print("🎨 Loading Base Image: \(baseImageName)")
            
            // 2. Add Base Shape Layer
            baseShapeLayer = UIImageView(frame: canvasContainerView.bounds)
            baseShapeLayer.contentMode = .scaleAspectFit
            baseShapeLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            if let img = UIImage(named: baseImageName) {
                baseShapeLayer.image = img
            } else {
                // Safety: Fallback to standard base if the specific "no_x" image is missing
                print("⚠️ Image \(baseImageName) not found. Using default.")
                baseShapeLayer.image = UIImage(named: "shape_\(shapeID)_base")
            }
            
            canvasContainerView.addSubview(baseShapeLayer)
            
            // 3. Add Feature Layers (Standard Z-Index Logic)
            let sortedCategories = categories.sorted {
                let index1 = layerOrder.firstIndex(of: $0.name) ?? 999
                let index2 = layerOrder.firstIndex(of: $1.name) ?? 999
                return index1 < index2
            }
            
            for cat in sortedCategories {
                let imgView = UIImageView(frame: canvasContainerView.bounds)
                imgView.contentMode = .scaleAspectFit
                imgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
                canvasContainerView.addSubview(imgView)
                partLayers[cat.name] = imgView
            }
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
	
		
	
		/// Sanitizes strings for filenames (e.g. "Spoon-shaped" -> "Spoon_shaped")
	func cleanForFilename(_ name: String) -> String {
		return name
			.replacingOccurrences(of: " ", with: "_")
			.replacingOccurrences(of: "-", with: "_")
	}
	
	func selectCategory(at index: Int) {
		guard index < categories.count else { return }
		currentCategoryIndex = index
		let cat = categories[index]
		
		categoryLabel.text = cat.name
		
		variationsCollectionView.reloadData()
		categoriesCollectionView.selectItem(at: IndexPath(item: index, section: 0), animated: true, scrollPosition: .centeredHorizontally)
	}
	
	func updateCanvas(category: String, variant: String) {
		let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
		let cleanCategory = cleanForFilename(category)
		let cleanVariant = cleanForFilename(variant)
		
		let imageName = "canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
		
			// Debug print to help you find missing images
		print("🎨 Loading Canvas Image: \(imageName)")
		
		if let layer = partLayers[category] {
			if let image = UIImage(named: imageName) {
				layer.image = image
			} else {
				print("⚠️ Image not found: \(imageName)")
			}
		}
	}
   
	private func compositePreviewImage(base: UIImage, overlay: UIImage) -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: base.size)
		return renderer.image { _ in
			base.draw(in: CGRect(origin: .zero, size: base.size))
			overlay.draw(in: CGRect(origin: .zero, size: base.size))
		}
	}
	
	private func variationThumbnailImage(shapeID: String, categoryName: String, variantName: String) -> UIImage? {
		let cleanCategory = cleanForFilename(categoryName)
		let cleanVariant = cleanForFilename(variantName)
		
		let canvasName = "canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
		let iconName = "icon_\(cleanCategory)_\(cleanVariant)"
		let baseName = "shape_\(shapeID)_base"
		
		if let canvas = UIImage(named: canvasName) {
			if let base = UIImage(named: baseName) {
				return compositePreviewImage(base: base, overlay: canvas)
			}
			return canvas
		}
		
		return UIImage(named: iconName)
	}
	
	func getVariantsForCurrentCategory() -> [String] {
		guard currentCategoryIndex < categories.count else { return [] }
		let currentName = categories[currentCategoryIndex].name
		
		if let fieldMark = viewModel.referenceFieldMarks.first(where: { $0.area == currentName }) {
			return fieldMark.variants
		}
		return []
	}
	
	@objc private func nextTapped() {
		var marks: [FieldMarkData] = []
		for (area, variant) in selectedVariations {
				// Note: Colors are empty for now as per your prototype scope
			marks.append(FieldMarkData(area: area, variant: variant, colors: []))
		}
		
		viewModel.filterBirds(
			shape: viewModel.selectedShapeId,
			size: viewModel.selectedSizeCategory,
			location: viewModel.selectedLocation,
			fieldMarks: marks
		)
		
		delegate?.didFinishStep()
	}
}

	
extension GUIViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if collectionView == categoriesCollectionView {
			return categories.count
		} else {
			return getVariantsForCurrentCategory().count
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		if collectionView == categoriesCollectionView {
				// BOTTOM BAR (Categories)
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
			let item = categories[indexPath.row]
			
			cell.configure(name: item.name, iconName: item.imageView, isSelected: indexPath.row == currentCategoryIndex)
			return cell
			
		} else {
				// TOP BAR (Variations)
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VariationCell", for: indexPath) as! VariationCell
			let variants = getVariantsForCurrentCategory()
			let variantName = variants[indexPath.row]
			let categoryName = categories[currentCategoryIndex].name
			
			let isSelected = selectedVariations[categoryName] == variantName
			let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
			let thumb = variationThumbnailImage(shapeID: shapeID, categoryName: categoryName, variantName: variantName)
			cell.configure(image: thumb, isSelected: isSelected)
			return cell
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		if collectionView == categoriesCollectionView {
			selectCategory(at: indexPath.row)
		} else {
			let variants = getVariantsForCurrentCategory()
			let selectedVariant = variants[indexPath.row]
			let categoryName = categories[currentCategoryIndex].name
			
			print("👉 Selected: \(categoryName) - \(selectedVariant)")
			
			selectedVariations[categoryName] = selectedVariant
			variationsCollectionView.reloadData()
			updateCanvas(category: categoryName, variant: selectedVariant)
		}
	}
	
		
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
			// I restored the sizes from your original code (70 and 60)
			// because you mentioned they worked better than the larger ones.
		if collectionView == categoriesCollectionView {
			return CGSize(width: 70, height: 70)
		} else {
			return CGSize(width: 60, height: 60)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		return 15
	}
}
