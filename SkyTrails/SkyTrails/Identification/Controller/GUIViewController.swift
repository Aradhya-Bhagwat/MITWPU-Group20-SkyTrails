import UIKit

class GUIViewController: UIViewController {
	
		
	@IBOutlet weak var variationsCollectionView: UICollectionView!
	@IBOutlet weak var canvasContainerView: UIView!
	@IBOutlet weak var categoryLabel: UILabel!
	@IBOutlet weak var categoriesCollectionView: UICollectionView!
	
		
	var viewModel: IdentificationManager!
	weak var delegate: IdentificationFlowStepDelegate?
	
	private var categories: [ChooseFieldMark] = []
	private var currentCategoryIndex: Int = 0

	private var selectedVariations: [String: String] = [:]
	
	private var baseShapeLayer: UIImageView!
	private var partLayers: [String: UIImageView] = [:]
	

	
    private let layerOrder = [
        "Tail",
        "Leg",
        "Thigh",
        "Head",
        "Neck",
        "Back", "Belly", "Chest",
        "Nape", "Throat", "Crown",
        "Facemask",
        "Beak", "Eye",
        "Wings"
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
		setupRightTickButton()
		
		if !categories.isEmpty {
			selectCategory(at: 0)
		}
	}
	
		
	private func loadData() {
		guard let selectedNames = viewModel.data.fieldMarks, !selectedNames.isEmpty else {
			self.categories = []
			return
		}
        let allParts = viewModel.chooseFieldMarks
		self.categories = allParts.filter { part in
			return selectedNames.contains(part.name)
		}
        
        if selectedVariations["Neck"] == nil { selectedVariations["Neck"] = "Default" }
        if selectedVariations["Head"] == nil { selectedVariations["Head"] = "Default" }
        setupCanvas()
	}
	
	private func setupUI() {
		title = "Identify field marks"
		variationsCollectionView.delegate = self
		variationsCollectionView.dataSource = self
		categoriesCollectionView.delegate = self
		categoriesCollectionView.dataSource = self
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

        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
        let userSelectedCategories = categories.map { $0.name }

        baseShapeLayer = UIImageView(frame: canvasContainerView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        baseShapeLayer.image = UIImage(named: "shape_\(shapeID)_base_Core")
        canvasContainerView.addSubview(baseShapeLayer)

        for catName in layerOrder {
            let imgView = UIImageView(frame: canvasContainerView.bounds)
            imgView.contentMode = .scaleAspectFit
            canvasContainerView.addSubview(imgView)
            partLayers[catName] = imgView

            var imageName: String? = nil

            if userSelectedCategories.contains(catName) {
                if let selectedVariant = selectedVariations[catName] {
                    imageName = "canvas_\(shapeID)_\(catName)_\(selectedVariant)"
                } else {
                    imageName = nil
                }
            } else {
                imageName = "canvas_\(shapeID)_\(catName)_Default"
            }
            if let name = imageName, let img = UIImage(named: name) {
                imgView.image = img
            } else {
                imgView.image = nil
            }
            
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
	
//	func updateCanvas(category: String, variant: String) {
//		let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
//		let cleanCategory = cleanForFilename(category)
//		let cleanVariant = cleanForFilename(variant)
//		
//		let imageName = "canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
//		
//			// Debug print to help you find missing images
//		print("🎨 Loading Canvas Image: \(imageName)")
//		
//		if let layer = partLayers[category] {
//			if let image = UIImage(named: imageName) {
//				layer.image = image
//			} else {
//				print("⚠️ Image not found: \(imageName)")
//			}
//		}
//        if category == "Neck" {
//                applyNeckOffset(variant: variant)
//            }
//	}
//
    func updateCanvas(category: String, variant: String) {
        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "Finch")
        let imageName = "canvas_\(shapeID)_\(cleanForFilename(category))_\(cleanForFilename(variant))"
        
        if let layer = partLayers[category] {
            layer.image = UIImage(named: imageName)
        }
        
//        if category == "Neck" {
//            applyNeckOffset(variant: variant)
//        }
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
