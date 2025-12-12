	//
	//  GUIViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 09/12/25.
	//

import UIKit

class GUIViewController: UIViewController {
	
		// MARK: - Outlets
	@IBOutlet weak var variationsCollectionView: UICollectionView!
	@IBOutlet weak var canvasContainerView: UIView!
	@IBOutlet weak var categoryLabel: UILabel!
	@IBOutlet weak var categoriesCollectionView: UICollectionView!
	
		// MARK: - Properties
	var viewModel: ViewModel!
	weak var delegate: IdentificationFlowStepDelegate?
	
		// Data Sources
		// ✅ FIX: Changed type to [ChooseFieldMark] because that is where "Beak", "Eye" etc. live.
	private var categories: [ChooseFieldMark] = []
	private var currentCategoryIndex: Int = 0
	
		// State
	private var selectedVariations: [String: String] = [:]
	
		// Canvas Layers
	private var baseShapeLayer: UIImageView!
	private var partLayers: [String: UIImageView] = [:]
	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		
		let variationNib = UINib(nibName: "VariationCell", bundle: nil)
		variationsCollectionView.register(variationNib, forCellWithReuseIdentifier: "VariationCell")
		let categoryNib = UINib(nibName: "CategoryCell", bundle: nil)
		categoriesCollectionView.register(categoryNib, forCellWithReuseIdentifier: "CategoryCell")
		
		setupCanvas()
		loadData()
		setupRightTickButton()
		
		if !categories.isEmpty {
			selectCategory(at: 0)
		}
	}
	
		// MARK: - Data Loading (THE FIX)
	private func loadData() {
			// 1. Get the names you selected (e.g. "Beak", "Eye")
		guard let selectedNames = viewModel.data.fieldMarks, !selectedNames.isEmpty else {
			print("⚠️ No user selection found.")
			self.categories = []
			return
		}
		
			// 2. Use 'fieldMarks' (The list of Body Parts), NOT 'fieldMarkOptions'
		let allParts = viewModel.fieldMarks
		
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
		
		if let layout = variationsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
			layout.estimatedItemSize = .zero
		}
		if let layout = categoriesCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
			layout.estimatedItemSize = .zero
			layout.scrollDirection = .horizontal
		}
	}
	
	private func setupCanvas() {
		baseShapeLayer = UIImageView(frame: canvasContainerView.bounds)
		baseShapeLayer.contentMode = .scaleAspectFit
		baseShapeLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		
		let shapeID = viewModel.selectedShapeId ?? "Finch"
		baseShapeLayer.image = UIImage(named: "shape_\(shapeID)_base")
		canvasContainerView.addSubview(baseShapeLayer)
		
			// Use .name instead of .fieldMarkName
		for cat in categories {
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
	
		// MARK: - Logic
	func selectCategory(at index: Int) {
		guard index < categories.count else { return }
		currentCategoryIndex = index
		let cat = categories[index]
		
			// ✅ FIX: Use .name
		categoryLabel.text = cat.name
		print("\(cat.name) category selected")
		
		variationsCollectionView.reloadData()
		categoriesCollectionView.selectItem(at: IndexPath(item: index, section: 0), animated: true, scrollPosition: .centeredHorizontally)
	}
	
	func updateCanvas(category: String, variant: String) {
		let shapeID = viewModel.selectedShapeId ?? "Finch"
		let imageName = "canvas_\(shapeID)_\(category)_\(variant)"
		if let layer = partLayers[category] {
			layer.image = UIImage(named: imageName)
		}
	}
	
	func getVariantsForCurrentCategory() -> [String] {
		guard currentCategoryIndex < categories.count else { return [] }
		
			// ✅ FIX: Use .name
		let currentName = categories[currentCategoryIndex].name
		
		if let fieldMark = viewModel.referenceFieldMarks.first(where: { $0.area == currentName }) {
			return fieldMark.variants
		}
		
		return []
	}
	
	@objc private func nextTapped() {
		var marks: [FieldMarkData] = []
		for (area, variant) in selectedVariations {
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

// MARK: - CollectionView Delegate & DataSource
extension GUIViewController: UICollectionViewDelegate, UICollectionViewDataSource {
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if collectionView == categoriesCollectionView {
			return categories.count
		} else {
			return getVariantsForCurrentCategory().count
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		if collectionView == categoriesCollectionView {
				// BOTTOM BAR
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
			let item = categories[indexPath.row]
			
				// ✅ FIX: Use .name and .imageView (from ChooseFieldMark)
			cell.configure(name: item.name, iconName: item.imageView, isSelected: indexPath.row == currentCategoryIndex)
			return cell
			
		} else {
				// TOP BAR
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VariationCell", for: indexPath) as! VariationCell
			let variants = getVariantsForCurrentCategory()
			let variantName = variants[indexPath.row]
			
				// ✅ FIX: Use .name
			let currentCatName = categories[currentCategoryIndex].name
			let isSelected = selectedVariations[currentCatName] == variantName
			
			let iconName = "icon_\(currentCatName)_\(variantName)"
			cell.configure(imageName: iconName, isSelected: isSelected)
			return cell
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		if collectionView == categoriesCollectionView {
			selectCategory(at: indexPath.row)
		} else {
			let variants = getVariantsForCurrentCategory()
			let selectedVariant = variants[indexPath.row]
			
				// ✅ FIX: Use .name
			let categoryName = categories[currentCategoryIndex].name
			
			print("\(categoryName) category \(selectedVariant) variant selected")
			
			selectedVariations[categoryName] = selectedVariant
			variationsCollectionView.reloadData()
			updateCanvas(category: categoryName, variant: selectedVariant)
		}
	}
}

extension GUIViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		return collectionView == categoriesCollectionView ? CGSize(width: 70, height: 70) : CGSize(width: 60, height: 60)
	}
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		return 15
	}
}
