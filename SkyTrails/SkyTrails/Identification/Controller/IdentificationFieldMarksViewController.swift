import UIKit
import SwiftData

class IdentificationFieldMarksViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var CanvasView: UIView!
    @IBOutlet weak var Categories: UICollectionView!
    @IBOutlet weak var progressView: UIProgressView!
    
    weak var delegate: IdentificationFlowStepDelegate?
    var selectedFieldMarks: [Int] = []
    
    var viewModel: IdentificationManager!
    private var availableMarks: [BirdFieldMark] {
        return viewModel.selectedShape?.fieldMarks ?? []
    }

    private var baseShapeLayer: UIImageView!
    private var partLayers: [String: UIImageView] = [:]
    private var layerLoadTasks: [String: Task<Void, Never>] = [:]

    private let layerOrder = [
        "Tail", "Leg", "Thigh", "Head", "Neck", "Back", "Underparts",
        "Nape", "Throat", "Crown", "Facemask", "Beak", "Eye", "Wings"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Identify Markings"
        self.tabBarItem.title = "Identification"
        setupUI()
        for (index, mark) in availableMarks.enumerated() {
            if viewModel.tempSelectedAreas.contains(mark.area) {
                selectedFieldMarks.append(index)
            }
        }
        
        setupCanvasIfNeeded()
        Categories.reloadData()
        updateNextButtonState()
    }

    private func updateNextButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !selectedFieldMarks.isEmpty
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = CanvasView.bounds
        baseShapeLayer?.frame = bounds
        for layer in partLayers.values {
            layer.frame = bounds
        }
    }
    
    func setupUI() {
        let categoryNib = UINib(nibName: "CategoryCell", bundle: nil)
        Categories.register(categoryNib, forCellWithReuseIdentifier: "CategoryCell")
        
        Categories.delegate = self
        Categories.dataSource = self
        Categories.allowsMultipleSelection = true
        Categories.backgroundColor = .clear
        
        if let layout = Categories.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = .zero
        }
    }
    
    func cleanForFilename(_ name: String) -> String {
        if name == "Passeridae_Fringillidae" { return "finch" }
        return name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
    
    private func setupCanvasIfNeeded() {
        guard CanvasView.subviews.isEmpty else { return }
        
        layerLoadTasks.values.forEach { $0.cancel() }
        layerLoadTasks.removeAll()
        partLayers.removeAll()

        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
        
        baseShapeLayer = UIImageView(frame: CanvasView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        let baseCoreKey = "id_shape_\(shapeID)_base_core"
        let baseCoreFallback = UIImage(named: baseCoreKey)
        baseShapeLayer.image = baseCoreFallback
        baseShapeLayer.layer.zPosition = -1
        CanvasView.addSubview(baseShapeLayer)
        loadBaseCoreImage(key: baseCoreKey, fallback: baseCoreFallback, shapeId: shapeID)

        for (index, catName) in layerOrder.enumerated() {
            let imgView = UIImageView(frame: CanvasView.bounds)
            imgView.contentMode = .scaleAspectFit
            imgView.layer.zPosition = CGFloat(index)
            
            CanvasView.addSubview(imgView)
            partLayers[catName] = imgView
            updateLayer(category: catName)
        }
    }
    
    func updateLayer(category: String) {
        guard let layer = partLayers[category] else { return }
        
        let shapeID = cleanForFilename(viewModel.selectedShapeId ?? "finch")
        let cleanCategory = cleanForFilename(category)
        
        let isSelected = isCategorySelected(name: category)

        let defaultProfileCategories: Set<String> = ["beak", "head", "leg", "tail"]
        let defaultName = defaultProfileCategories.contains(cleanCategory)
            ? "id_canvas_\(shapeID)_\(cleanCategory)_default"
            : nil
        let defaultImage = defaultName.flatMap { UIImage(named: $0) }

        if isSelected {
            let selectedAssetNames = [
                "canvas_\(shapeID)_\(cleanCategory)_color",
            ]
            layer.image = selectedAssetNames.lazy.compactMap { UIImage(named: $0) }.first ?? defaultImage
            var candidates = selectedAssetNames
            if let defaultName {
                candidates.append(defaultName)
            }
            loadBestImage(for: category, candidates: candidates, fallback: layer.image ?? defaultImage, shapeId: shapeID)
        } else {
            layer.image = defaultImage
            if let defaultName {
                loadBestImage(for: category, candidates: [defaultName], fallback: defaultImage, shapeId: shapeID)
            } else {
                layerLoadTasks[category]?.cancel()
            }
        }
    }

    private func loadBestImage(for category: String, candidates: [String], fallback: UIImage?, shapeId: String) {
        layerLoadTasks[category]?.cancel()
        print("[DEBUG-FIELDMARK] Loading images for category: \(category), shapeId: \(shapeId)")
        print("[DEBUG-FIELDMARK] Candidates: \(candidates)")
        for key in candidates {
            let exists = UIImage(named: key) != nil
            print("[DEBUG-FIELDMARK] Bundle: \(key) - exists: \(exists)")
        }
        layerLoadTasks[category] = Task { [weak self] in
            guard let self else { return }
            var selectedImage: UIImage?
            for key in candidates {
                let img = await IdentificationImageService.shared.image(for: key, shapeId: shapeId)
                print("[DEBUG-FIELDMARK] Remote: \(key) - loaded: \(img != nil)")
                if let img {
                    selectedImage = img
                    break
                }
            }
            guard !Task.isCancelled else { return }
            guard let layer = self.partLayers[category] else { return }
            if selectedImage == nil {
                print("[DEBUG-FIELDMARK] FAILED to load: \(candidates) for \(category)")
            }
            layer.image = selectedImage ?? fallback
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
    
    func isCategorySelected(name: String) -> Bool {
        return selectedFieldMarks.contains { index in
            availableMarks.indices.contains(index) && availableMarks[index].area == name
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return availableMarks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
        let item = availableMarks[indexPath.row]
        
        let isSelected = selectedFieldMarks.contains(indexPath.row)
        if isSelected {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }

      
        cell.configure(name: item.area, iconName: item.iconName, isSelected: isSelected)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if selectedFieldMarks.count >= 5 {
            showMaxLimitAlert()
            return false
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.row
        if !selectedFieldMarks.contains(index) {
            selectedFieldMarks.append(index)
        }
        
        let categoryName = availableMarks[index].area
        updateLayer(category: categoryName)
        updateNextButtonState()
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let index = indexPath.row
        if let position = selectedFieldMarks.firstIndex(of: index) {
            selectedFieldMarks.remove(at: position)
        }
        
        collectionView.reloadItems(at: [indexPath])
        let categoryName = availableMarks[index].area
        updateLayer(category: categoryName)
        updateNextButtonState()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 147, height: 100)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 15
    }

    private func showMaxLimitAlert() {
        let alert = UIAlertController(title: "Limit Reached", message: "You can select at most 5 field marks.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func nextTapped(_ sender: Any) {
        guard !selectedFieldMarks.isEmpty else { return }
        let selectedMarkObjects = selectedFieldMarks.compactMap { index -> BirdFieldMark? in
            availableMarks.indices.contains(index) ? availableMarks[index] : nil
        }
        viewModel.tempSelectedAreas = selectedMarkObjects.map { $0.area }
        
        viewModel.filterBirds(
            shape: viewModel.selectedShapeId,
            size: viewModel.selectedSizeCategory,
            location: viewModel.selectedLocation,
            fieldMarks: selectedMarkObjects
        )
        
        delegate?.didFinishStep()
    }
}

extension IdentificationFieldMarksViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
