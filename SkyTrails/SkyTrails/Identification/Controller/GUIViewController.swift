import UIKit
import SwiftData

class GUIViewController: UIViewController {
    
    @IBOutlet weak var variationsCollectionView: UICollectionView!
    @IBOutlet weak var canvasContainerView: UIView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    @IBOutlet weak var variationHeaderView: UIView!
    @IBOutlet weak var selectedImageView: UIImageView!
    @IBOutlet weak var chevronImageView: UIImageView!
    @IBOutlet weak var selectedContainerView: UIView!
    @IBOutlet weak var chevronContainerView: UIView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    private var categories: [BirdFieldMark] = []
    private var currentCategoryIndex: Int = 0
    private var selectedVariations: [String: String] = [:]
    private var isVariationsExpanded: Bool = false
    
    private var baseShapeLayer: UIImageView!
    private var partLayers: [String: UIImageView] = [:]
    private var layerLoadTasks: [String: Task<Void, Never>] = [:]
    private var variationThumbnailTasks: [IndexPath: Task<Void, Never>] = [:]
    private var headerThumbnailTask: Task<Void, Never>?
    private var variationThumbnailCache: [String: UIImage] = [:]
    private var lastLayoutSize: CGSize = .zero
    
    private let layerOrder = [
        "Tail", "Leg", "Thigh", "Head", "Neck", "Back", "Underparts",
        "Nape", "Throat", "Crown", "Facemask", "Beak", "Eye", "Wings"
    ]

    deinit {
        cancelVariationThumbnailTasks()
        headerThumbnailTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        let variationNib = UINib(nibName: "VariationCell", bundle: nil)
        variationsCollectionView.register(variationNib, forCellWithReuseIdentifier: "VariationCell")
        let categoryNib = UINib(nibName: "CategoryCell", bundle: nil)
        categoriesCollectionView.register(categoryNib, forCellWithReuseIdentifier: "CategoryCell")
        
        loadData()
        setupCanvasIfNeeded()
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

        guard view.bounds.size != lastLayoutSize else { return }
        lastLayoutSize = view.bounds.size
        categoriesCollectionView.collectionViewLayout.invalidateLayout()
        variationsCollectionView.collectionViewLayout.invalidateLayout()
    }
    
    private func loadData() {
        guard !viewModel.tempSelectedAreas.isEmpty else {
            self.categories = []
            return
        }
        let allMarksForShape = viewModel.selectedShape?.fieldMarks ?? []
        self.categories = allMarksForShape.filter { viewModel.tempSelectedAreas.contains($0.area) }
        for mark in categories {
            if let variant = viewModel.selectedFieldMarks[mark.bird_field_mark_id] {
                selectedVariations[mark.area] = variant.name
            }
        }
    }
    
    private func setupUI() {
        title = "Identify field marks"
        categoryLabel.isHidden = true
        variationsCollectionView.delegate = self
        variationsCollectionView.dataSource = self
        categoriesCollectionView.delegate = self
        categoriesCollectionView.dataSource = self
        variationsCollectionView.backgroundColor = .clear
        categoriesCollectionView.backgroundColor = .clear
        categoriesCollectionView.showsHorizontalScrollIndicator = false
        categoriesCollectionView.isScrollEnabled = true
        
        if let layout = variationsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.scrollDirection = .vertical
        }
        if let layout = categoriesCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.scrollDirection = .horizontal
        }

        setupVariationHeader()
    }

    private func setupVariationHeader() {
        [selectedContainerView, chevronContainerView].forEach { view in
            view?.layer.cornerRadius = 12
            view?.layer.borderWidth = 1
            view?.layer.borderColor = UIColor.systemGray.cgColor
            view?.backgroundColor = .systemBackground
            view?.isUserInteractionEnabled = true
        }

        selectedContainerView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(selectedTapped))
        )
        chevronContainerView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(chevronTapped))
        )

        selectedImageView.contentMode = .scaleAspectFit
        chevronImageView.contentMode = .center
        updateVariationHeader()
    }

    private func setupCanvasIfNeeded() {
        guard canvasContainerView.subviews.isEmpty else { return }
        
        layerLoadTasks.values.forEach { $0.cancel() }
        layerLoadTasks.removeAll()
        partLayers.removeAll()

        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
        let userSelectedAreaNames = categories.map { $0.area }

        baseShapeLayer = UIImageView(frame: canvasContainerView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        let baseCoreKey = "id_shape_\(shapeID)_base_core"
        let baseCoreFallback = UIImage(named: baseCoreKey)
        baseShapeLayer.image = baseCoreFallback
        loadBaseCoreImage(key: baseCoreKey, fallback: baseCoreFallback, shapeId: shapeID)
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
                let fallback = UIImage(named: name)
                imgView.image = fallback
                loadLayerImage(category: catName, key: name, fallback: fallback, shapeId: shapeID)
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
        isVariationsExpanded = false
        let mark = categories[index]
        
        categoryLabel.text = mark.area
        cancelVariationThumbnailTasks()
        variationsCollectionView.reloadData()
        updateVariationHeader()
        categoriesCollectionView.selectItem(at: IndexPath(item: index, section: 0), animated: true, scrollPosition: .centeredHorizontally)
    }

    func updateCanvas(category: String, variant: String) {
        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
        let imageName = "id_canvas_\(shapeID)_\(cleanForFilename(category))_\(cleanForFilename(variant))"
        
        if let layer = partLayers[category] {
            let fallback = UIImage(named: imageName)
            layer.image = fallback
            loadLayerImage(category: category, key: imageName, fallback: fallback, shapeId: shapeID)
        }
    }

    private func loadLayerImage(category: String, key: String, fallback: UIImage?, shapeId: String? = nil) {
        layerLoadTasks[category]?.cancel()
        layerLoadTasks[category] = Task { [weak self] in
            let loaded = await IdentificationImageService.shared.image(for: key, shapeId: shapeId)
            guard !Task.isCancelled else { return }
            guard let self, let layer = self.partLayers[category] else { return }
            layer.image = loaded ?? fallback
        }
    }

    private func loadBaseCoreImage(key: String, fallback: UIImage?, shapeId: String) {
        Task { [weak self] in
            let loaded = await IdentificationImageService.shared.image(for: key, shapeId: shapeId)
            guard !Task.isCancelled else { return }
            guard let self, let baseLayer = self.baseShapeLayer else { return }
            baseLayer.image = loaded ?? fallback
        }
    }

    private func variationThumbnailImage(shapeID: String, categoryName: String, variantName: String) -> UIImage? {
        let cleanCategory = cleanForFilename(categoryName)
        let cleanVariant = cleanForFilename(variantName)
        
        let isKiteShape = shapeID == "Accipitridae" || shapeID.lowercased().contains("kite")
        let canvasName = "id_canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
        let baseName = "id_shape_\(shapeID)_base"
        
        if !isKiteShape {
            if let cachedBase = IdentificationImageService.shared.cachedImage(for: baseName, shapeId: shapeID),
               let cachedCanvas = IdentificationImageService.shared.cachedImage(for: canvasName, shapeId: shapeID) {
                return composeThumbnail(base: cachedBase, canvas: cachedCanvas)
            }
            
            if let canvas = UIImage(named: canvasName), let base = UIImage(named: baseName) {
                let renderer = UIGraphicsImageRenderer(size: base.size)
                return renderer.image { _ in
                    base.draw(in: CGRect(origin: .zero, size: base.size))
                    canvas.draw(in: CGRect(origin: .zero, size: base.size))
                }
            }
        }
        
        let capitalizedShape = shapeID.prefix(1).uppercased() + shapeID.dropFirst()
        let alternateCanvasName = "canvas_\(capitalizedShape)_\(cleanCategory)_\(cleanVariant)"
        let alternateBaseName = "shape_\(capitalizedShape)_base"
        
        if let canvas = UIImage(named: alternateCanvasName) {
            if !isKiteShape, let base = UIImage(named: alternateBaseName) {
                let renderer = UIGraphicsImageRenderer(size: base.size)
                return renderer.image { _ in
                    base.draw(in: CGRect(origin: .zero, size: base.size))
                    canvas.draw(in: CGRect(origin: .zero, size: base.size))
                }
            }
            return canvas
        }
        
        let bundleCanvas = UIImage(named: canvasName)
        let bundleBase = UIImage(named: baseName)
        let bundleIcon = UIImage(named: "id_icon_\(cleanCategory)_\(cleanVariant)")

        return bundleIcon
    }
    
    private func composeThumbnail(base: UIImage, canvas: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: base.size)
        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: base.size))
            canvas.draw(in: CGRect(origin: .zero, size: base.size))
        }
    }

    private func variationThumbnailCacheKey(shapeID: String, categoryName: String, variantName: String) -> String {
        "\(shapeID)|\(cleanForFilename(categoryName))|\(cleanForFilename(variantName))"
    }

    private func loadVariationThumbnailRemotely(
        for cell: VariationCell,
        at indexPath: IndexPath,
        shapeID: String,
        categoryName: String,
        variantName: String,
        isSelected: Bool
    ) {
        variationThumbnailTasks[indexPath]?.cancel()

        let cleanCategory = cleanForFilename(categoryName)
        let cleanVariant = cleanForFilename(variantName)
        let isKiteShape = shapeID == "Accipitridae" || shapeID.lowercased().contains("kite")
        let canvasName = "id_canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
        let baseName = "id_shape_\(shapeID)_base"
        
        let capitalizedShape = shapeID.prefix(1).uppercased() + shapeID.dropFirst()
        let altCanvasName = "canvas_\(capitalizedShape)_\(cleanCategory)_\(cleanVariant)"
        let altBaseName = "shape_\(capitalizedShape)_base"
        
        let cacheKey = variationThumbnailCacheKey(shapeID: shapeID, categoryName: categoryName, variantName: variantName)

        if let cached = variationThumbnailCache[cacheKey] {
            cell.configure(image: cached, isSelected: isSelected)
            return
        }

        if !isKiteShape, let diskCached = IdentificationImageService.shared.loadComposedThumbnail(cacheKey: cacheKey) {
            variationThumbnailCache[cacheKey] = diskCached
            cell.configure(image: diskCached, isSelected: isSelected)
            return
        }

        variationThumbnailTasks[indexPath] = Task { [weak self, weak cell] in
            guard let self else { return }
            
            var remoteBase: UIImage?
            var remoteCanvas: UIImage?
            
            if !isKiteShape {
                remoteBase = await IdentificationImageService.shared.image(for: baseName, shapeId: shapeID)
                if remoteBase == nil {
                    remoteBase = await IdentificationImageService.shared.image(for: altBaseName, shapeId: shapeID)
                }
            }
            
            remoteCanvas = await IdentificationImageService.shared.image(for: canvasName, shapeId: shapeID)
            if remoteCanvas == nil {
                remoteCanvas = await IdentificationImageService.shared.image(for: altCanvasName, shapeId: shapeID)
            }
            
            guard !Task.isCancelled else { return }

            let composed: UIImage? = {
                if !isKiteShape, let base = remoteBase, let canvas = remoteCanvas {
                    let renderer = UIGraphicsImageRenderer(size: base.size)
                    return renderer.image { _ in
                        base.draw(in: CGRect(origin: .zero, size: base.size))
                        canvas.draw(in: CGRect(origin: .zero, size: base.size))
                    }
                } else if let canvas = remoteCanvas {
                    return canvas
                }
                return nil
            }()

            guard let thumb = composed else { return }
            self.variationThumbnailCache[cacheKey] = thumb
            if !isKiteShape {
                IdentificationImageService.shared.saveComposedThumbnail(thumb, cacheKey: cacheKey)
            }
            guard let cell else { return }
            guard let currentIndexPath = self.variationsCollectionView.indexPath(for: cell),
                  currentIndexPath == indexPath else { return }

            cell.configure(image: thumb, isSelected: isSelected)
        }
    }

    private func cancelVariationThumbnailTasks() {
        variationThumbnailTasks.values.forEach { $0.cancel() }
        variationThumbnailTasks.removeAll()
        headerThumbnailTask?.cancel()
    }

    private func updateVariationHeader() {
        let variants = getOrderedVariantsForCurrentCategory()
        let hasVariants = !variants.isEmpty
        variationHeaderView.isHidden = !hasVariants

        guard hasVariants, currentCategoryIndex < categories.count else {
            selectedImageView.image = nil
            chevronImageView.image = nil
            return
        }

        let firstVariant = variants[0]
        let categoryName = categories[currentCategoryIndex].area
        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
        let cacheKey = variationThumbnailCacheKey(shapeID: shapeID, categoryName: categoryName, variantName: firstVariant.name)
        let thumb = variationThumbnailCache[cacheKey]
            ?? IdentificationImageService.shared.loadComposedThumbnail(cacheKey: cacheKey)
            ?? variationThumbnailImage(shapeID: shapeID, categoryName: categoryName, variantName: firstVariant.name)
        selectedImageView.image = thumb ?? UIImage(named: "id_icn_field_marks")

        let selectedName = selectedVariations[categoryName]
        let isHeaderSelected = selectedName == nil || selectedName == firstVariant.name
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        selectedContainerView.layer.borderWidth = isHeaderSelected ? 2 : 1
        selectedContainerView.layer.borderColor = isHeaderSelected ? UIColor.systemBlue.cgColor : UIColor.systemGray.cgColor
        selectedContainerView.backgroundColor = isHeaderSelected
            ? UIColor.systemBlue.withAlphaComponent(isDarkMode ? 0.24 : 0.10)
            : .systemBackground

        chevronImageView.image = UIImage(systemName: isVariationsExpanded ? "chevron.up" : "chevron.down")
        chevronImageView.tintColor = .systemGray

        loadHeaderThumbnailRemotely(
            shapeID: shapeID,
            categoryName: categoryName,
            variantName: firstVariant.name,
            isSelected: isHeaderSelected
        )
    }

    private func loadHeaderThumbnailRemotely(
        shapeID: String,
        categoryName: String,
        variantName: String,
        isSelected: Bool
    ) {
        headerThumbnailTask?.cancel()

        let cleanCategory = cleanForFilename(categoryName)
        let cleanVariant = cleanForFilename(variantName)
        let canvasName = "id_canvas_\(shapeID)_\(cleanCategory)_\(cleanVariant)"
        let baseName = "id_shape_\(shapeID)_base"
        
        let capitalizedShape = shapeID.prefix(1).uppercased() + shapeID.dropFirst()
        let altCanvasName = "canvas_\(capitalizedShape)_\(cleanCategory)_\(cleanVariant)"
        let altBaseName = "shape_\(capitalizedShape)_base"
        
        let cacheKey = variationThumbnailCacheKey(shapeID: shapeID, categoryName: categoryName, variantName: variantName)

        if let cached = variationThumbnailCache[cacheKey] {
            selectedImageView.image = cached
            return
        }

        headerThumbnailTask = Task { [weak self] in
            guard let self else { return }
            
            var remoteBase = await IdentificationImageService.shared.image(for: baseName, shapeId: shapeID)
            var remoteCanvas = await IdentificationImageService.shared.image(for: canvasName, shapeId: shapeID)
            
            if remoteBase == nil {
                remoteBase = await IdentificationImageService.shared.image(for: altBaseName, shapeId: shapeID)
            }
            if remoteCanvas == nil {
                remoteCanvas = await IdentificationImageService.shared.image(for: altCanvasName, shapeId: shapeID)
            }
            
            guard !Task.isCancelled else { return }
            
            let thumb: UIImage? = {
                if let base = remoteBase, let canvas = remoteCanvas {
                    return self.composeThumbnail(base: base, canvas: canvas)
                } else if let canvas = remoteCanvas {
                    return canvas
                }
                return nil
            }()

            guard let finalThumb = thumb else { return }
            self.variationThumbnailCache[cacheKey] = finalThumb
            IdentificationImageService.shared.saveComposedThumbnail(finalThumb, cacheKey: cacheKey)

            guard self.currentCategoryIndex < self.categories.count else { return }
            let currentCategoryName = self.categories[self.currentCategoryIndex].area
            let currentSelectedName = self.selectedVariations[currentCategoryName]
            let isCurrentHeaderSelection = currentSelectedName == nil || currentSelectedName == variantName
            let shouldStillShow = currentCategoryName == categoryName && isCurrentHeaderSelection == isSelected
            guard shouldStillShow else { return }

            self.selectedImageView.image = finalThumb
        }
    }
    
    func getVariantsForCurrentCategory() -> [FieldMarkVariant] {
        guard currentCategoryIndex < categories.count else { return [] }
        let variants = categories[currentCategoryIndex].variants ?? []

        return variants
    }
    
    private func getOrderedVariantsForCurrentCategory() -> [FieldMarkVariant] {
        let variants = getVariantsForCurrentCategory()
        guard currentCategoryIndex < categories.count else { return variants }
        let categoryName = categories[currentCategoryIndex].area

        if let selectedName = selectedVariations[categoryName],
           let selectedIndex = variants.firstIndex(where: { $0.name == selectedName }) {
            var ordered = variants
            let selected = ordered.remove(at: selectedIndex)
            ordered.insert(selected, at: 0)
            return ordered
        }

        let preferredNames = ["default", "plain", "solid"]
        for preferred in preferredNames {
            if let index = variants.firstIndex(where: { cleanForFilename($0.name) == preferred }) {
                var ordered = variants
                let preferredVariant = ordered.remove(at: index)
                ordered.insert(preferredVariant, at: 0)
                return ordered
            }
        }

        return variants
    }

    @objc private func selectedTapped() {
        let variants = getOrderedVariantsForCurrentCategory()
        guard let first = variants.first, currentCategoryIndex < categories.count else { return }

        let currentMark = categories[currentCategoryIndex]
        selectedVariations[currentMark.area] = first.name
        viewModel.toggleVariant(first, for: currentMark)
        updateCanvas(category: currentMark.area, variant: first.name)
        updateVariationHeader()
        variationsCollectionView.reloadData()
        updateNextButtonState()
    }

    @objc private func chevronTapped() {
        isVariationsExpanded.toggle()
        updateVariationHeader()
        variationsCollectionView.reloadData()
    }
    
    @IBAction func nextTapped(_ sender: Any) {
        guard !selectedVariations.isEmpty else { return }
        delegate?.didFinishStep()
    }
}

extension GUIViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoriesCollectionView {
            return categories.count
        } else {
            let variants = getOrderedVariantsForCurrentCategory()
            return isVariationsExpanded ? max(0, variants.count - 1) : 0
        }
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
            let variants = getOrderedVariantsForCurrentCategory()
            let categoryName = categories[currentCategoryIndex].area
            let variant = variants[indexPath.row + 1]
            let isSelected = selectedVariations[categoryName] == variant.name
            let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
            let cacheKey = variationThumbnailCacheKey(shapeID: shapeID, categoryName: categoryName, variantName: variant.name)
            let thumb = variationThumbnailCache[cacheKey]
                ?? IdentificationImageService.shared.loadComposedThumbnail(cacheKey: cacheKey)
                ?? variationThumbnailImage(shapeID: shapeID, categoryName: categoryName, variantName: variant.name)
            cell.configure(image: thumb, isSelected: isSelected)
            loadVariationThumbnailRemotely(
                for: cell,
                at: indexPath,
                shapeID: shapeID,
                categoryName: categoryName,
                variantName: variant.name,
                isSelected: isSelected
            )
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoriesCollectionView {
            selectCategory(at: indexPath.row)
        } else {
            let variants = getOrderedVariantsForCurrentCategory()
            let variant = variants[indexPath.row + 1]
            let currentMark = categories[currentCategoryIndex]

            selectedVariations[currentMark.area] = variant.name
            viewModel.toggleVariant(variant, for: currentMark)

            variationsCollectionView.reloadData()
            updateVariationHeader()
            updateCanvas(category: currentMark.area, variant: variant.name)
            updateNextButtonState()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == categoriesCollectionView {
            let layout = (collectionViewLayout as? UICollectionViewFlowLayout) ?? UICollectionViewFlowLayout()
            let verticalInsets = layout.sectionInset.top + layout.sectionInset.bottom
            let usableHeight = max(collectionView.bounds.height - verticalInsets, 0)
            let height = floor(usableHeight * (5.0 / 6.0))
            let width = floor(height * 1.47)
            return CGSize(width: width, height: height)
        }

        let layout = (collectionViewLayout as? UICollectionViewFlowLayout) ?? UICollectionViewFlowLayout()
        let horizontalInsets = layout.sectionInset.left + layout.sectionInset.right
        let side = max(collectionView.bounds.width - horizontalInsets, 0)
        return CGSize(width: side, height: side)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
}
