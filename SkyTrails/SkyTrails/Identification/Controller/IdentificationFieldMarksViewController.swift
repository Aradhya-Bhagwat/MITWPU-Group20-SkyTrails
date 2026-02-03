import UIKit
import SwiftData

class IdentificationFieldMarksViewController: UIViewController {
    
    @IBOutlet weak var CanvasView: UIView!
    @IBOutlet weak var Categories: UICollectionView!
    @IBOutlet weak var progressView: UIProgressView!
    
    weak var delegate: IdentificationFlowStepDelegate?
    
    // Updated to store the actual model objects
    private var availableFieldMarks: [BirdFieldMark] = []
    private var selectedMarks: Set<BirdFieldMark> = []
    
    var viewModel: IdentificationManager!
    
    private var baseShapeLayer: UIImageView!
    private var partLayers: [String: UIImageView] = [:]
    
    private let layerOrder = [
        "Tail", "Leg", "Thigh", "Head", "Neck",
        "Back", "Underparts", "Nape", "Throat", "Crown",
        "Facemask", "Beak", "Eye", "Wings"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
        setupUI()
        setupCanvas()
    }
    
    private func loadData() {
        // Fetch field marks specifically for the selected shape from the manager
        if let shape = viewModel.selectedShape {
            self.availableFieldMarks = shape.fieldMarks?.sorted { $0.area < $1.area } ?? []
        }
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
        
        if let layout = Categories.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = .zero
        }
    }
    
    func cleanForFilename(_ name: String) -> String {
        if name == "Passeridae_Fringillidae" { return "finch" }
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
    
    private func setupCanvas() {
        CanvasView.subviews.forEach { $0.removeFromSuperview() }
        partLayers.removeAll()

        let shapeID = cleanForFilename(viewModel.selectedShape?.id ?? "finch")
        
        baseShapeLayer = UIImageView(frame: CanvasView.bounds)
        baseShapeLayer.contentMode = .scaleAspectFit
        baseShapeLayer.image = UIImage(named: "id_shape_\(shapeID)_base_core")
        baseShapeLayer.layer.zPosition = -1
        CanvasView.addSubview(baseShapeLayer)

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
        
        let shapeID = cleanForFilename(viewModel.selectedShape?.id ?? "finch")
        let cleanCategory = cleanForFilename(category)
        
        // Logic check: Is this area currently in our local selected set?
        let isSelected = selectedMarks.contains(where: { $0.area == category })
        
        let baseName = isSelected ?
            "canvas_\(shapeID)_\(cleanCategory)_color" :
            "id_canvas_\(shapeID)_\(cleanCategory)_default"
        
        layer.image = UIImage(named: baseName)
    }

    private func showMaxLimitAlert() {
        let alert = UIAlertController(title: "Limit Reached", message: "You can select at most 5 field marks.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func nextTapped(_ sender: Any) {
        // No longer using viewModel.data.fieldMarks (String array).
        // Instead, the next screen (GUI) will read from the 'selectedMarks' we've gathered.
        // We sync our local Selection to the manager if necessary, or pass it via navigation.
        
        // For filtering logic alignment:
        let selectedNames = selectedMarks.map { $0.area }
        
        // We temporarily store these in a way the GUIViewController can access
        // (You may need to add 'var selectedFieldMarkAreas: [String]' to IdentificationManager)
        viewModel.tempSelectedAreas = selectedNames
        
        viewModel.runFilter()
        delegate?.didFinishStep()
    }
}

// MARK: - CollectionView Logic
extension IdentificationFieldMarksViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return availableFieldMarks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
        let item = availableFieldMarks[indexPath.row]
        
        let isSelected = selectedMarks.contains(item)
        if isSelected {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }

        cell.configure(name: item.area, iconName: "id_icn_\(cleanForFilename(item.area))", isSelected: isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if selectedMarks.count >= 5 {
            showMaxLimitAlert()
            return false
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = availableFieldMarks[indexPath.row]
        selectedMarks.insert(item)
        updateLayer(category: item.area)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let item = availableFieldMarks[indexPath.row]
        selectedMarks.remove(item)
        
        collectionView.reloadItems(at: [indexPath])
        updateLayer(category: item.area)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 70, height: 70)
    }
}

extension IdentificationFieldMarksViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
