//
//  IdentificationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class IdentificationViewController: UIViewController, UITableViewDelegate,UITableViewDataSource,UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,UINavigationControllerDelegate{
    
    private var flowSteps: [IdentificationStep] = []
    private var currentStepIndex: Int = 0
    private var progressSteps: [IdentificationStep] = []
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var historyCollectionView: UICollectionView!
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var warningLabel: UILabel!
    var model: IdentificationManager = IdentificationManager()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
      applyCardShadow(to: startButton)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHistoryInteraction()
        tableView.reloadData()
        historyCollectionView.reloadData()
    }
  

    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "HistoryCollectionViewCell", bundle: nil)
        historyCollectionView.register(nib, forCellWithReuseIdentifier: "history_cell")
        updateHistoryInteraction()
        navigationController?.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        historyCollectionView.delegate = self
        historyCollectionView.dataSource = self
        setupHistoryFlowLayout()
        tableView.reloadData()
        historyCollectionView.reloadData()
        updateSelectionState()
    }
    
    
    func updateSelectionState() {
        let selectedCount = model.fieldMarkOptions.filter { $0.isSelected ?? false }.count
        let isValid = selectedCount >= 2

        warningLabel.isHidden = isValid
        startButton.isEnabled = isValid

        let titleColor: UIColor = isValid ? .black : .systemGray3
        let shadowOpacity: Float = isValid ? 0.1 : 0.05

        startButton.setTitleColor(titleColor, for: .normal)
        startButton.layer.shadowOpacity = shadowOpacity
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(model.histories.count, 1)
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let historyCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "history_cell",
            for: indexPath
        ) as! HistoryCollectionViewCell

        if model.histories.isEmpty {
            historyCell.showEmptyState()
        } else {
            let historyItem = model.histories[indexPath.row]
            historyCell.configureCell(historyItem: historyItem)
        }

        return historyCell
    }

    
    private func updateHistoryInteraction() {
        let isEmpty = model.histories.isEmpty

        historyCollectionView.isUserInteractionEnabled = !isEmpty
        historyCollectionView.alpha = isEmpty ? 0.6 : 1.0
    }

    func applyCardShadow(to view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor

    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.fieldMarkOptions.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        
        let item = model.fieldMarkOptions[indexPath.row]
        cell.textLabel?.text = item.fieldMarkName.rawValue
        
        if let img = UIImage(named: item.symbols) {
            
            let targetSize = CGSize(width: 28, height: 28)
            let resized = resize(img, to: targetSize)
            cell.imageView?.image = resized
            cell.imageView?.contentMode = .scaleAspectFit
            cell.imageView?.frame = CGRect(origin: .zero, size: targetSize)
            cell.imageView?.tintColor = .label
        } else {
            
            cell.imageView?.image = UIImage(systemName: "questionmark.circle")
            cell.imageView?.tintColor = .systemGray
        }
        
        cell.accessoryType = (item.isSelected ?? false) ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let currentState = model.fieldMarkOptions[indexPath.row].isSelected ?? false
        model.fieldMarkOptions[indexPath.row].isSelected = !currentState
        
        
        let tappedItemName = model.fieldMarkOptions[indexPath.row].fieldMarkName
        let isNowSelected = model.fieldMarkOptions[indexPath.row].isSelected ?? false
        
        if tappedItemName == .fieldMarks && isNowSelected {
            if let shapeIndex = model.fieldMarkOptions.firstIndex(where: {
                $0.fieldMarkName == .shape
            }) {
                model.fieldMarkOptions[shapeIndex].isSelected = true
            }
        }
        
        
        
        tableView.reloadData()
        
        
        updateSelectionState()
    }
    
    func setupHistoryFlowLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        historyCollectionView.collectionViewLayout = layout
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {

        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }

        let itemsPerRow: CGFloat =
            UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2

        let totalSpacing =
            layout.sectionInset.left +
            layout.sectionInset.right +
            layout.minimumInteritemSpacing * (itemsPerRow - 1)

        let width =
            (collectionView.bounds.width - totalSpacing) / itemsPerRow

        return CGSize(width: width, height: 230)
    }


    
    @IBAction func startButtonTapped(_ sender: UIButton) {

        startIdentificationFlow(from: model.fieldMarkOptions)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !model.histories.isEmpty else { return }
        let selectedHistory = model.histories[indexPath.row]
        
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        if let resultVC = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as? ResultViewController {
            resultVC.viewModel = self.model
            resultVC.historyItem = selectedHistory
            resultVC.historyIndex = indexPath.row
            resultVC.delegate = self
            self.navigationController?.pushViewController(resultVC, animated: true)
        }
    }
    
    
    func startIdentificationFlow(from options: [FieldMarkType]) {
        flowSteps.removeAll()
        
        
        let selected = options.filter { $0.isSelected ?? false }
        for option in selected {
            switch option.fieldMarkName {
            case .locationDate: flowSteps.append(.dateLocation)
            case .size:         flowSteps.append(.size)
            case .shape:        flowSteps.append(.shape)
            case .fieldMarks:   flowSteps.append(.fieldMarks)
            }
            
        }
        
        
        if selected.contains(where: { $0.fieldMarkName == .fieldMarks }) {
            flowSteps.append(.gui)
        }
        
        
        flowSteps.append(.result)
        
        
        progressSteps = flowSteps.filter { step in
            switch step {
            case .gui, .result: return false
            default: return true
            }
        }
        
        currentStepIndex = 0
        pushNextViewController()
    }

    
    func pushNextViewController() {
        guard currentStepIndex < flowSteps.count else {
            
            return
        }
        
        let step = flowSteps[currentStepIndex]
        
        
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        let vc: UIViewController
        
        switch step {
        case .dateLocation:
            let nextVC = storyboard.instantiateViewController(withIdentifier: "DateandLocationViewController") as! DateandLocationViewController
            nextVC.viewModel = self.model
            nextVC.delegate = self
            vc = nextVC
            
        case .size:
            let nextVC = storyboard.instantiateViewController(withIdentifier: "IdentificationSizeViewController") as! IdentificationSizeViewController
            nextVC.viewModel = self.model
            nextVC.delegate = self
            vc = nextVC
            
        case .shape:
            let nextVC = storyboard.instantiateViewController(withIdentifier: "IdentificationShapeViewController") as! IdentificationShapeViewController
            nextVC.viewModel = self.model
            nextVC.delegate = self
            nextVC.selectedSizeIndex = model.selectedSizeCategory
            nextVC.filteredShapes = model.birdShapes
            vc = nextVC
            
        case .fieldMarks:
            let nextVC = storyboard.instantiateViewController(withIdentifier: "IdentificationFieldMarksViewController") as! IdentificationFieldMarksViewController
            nextVC.viewModel = self.model
            nextVC.delegate = self
            vc = nextVC
            
        case .gui:
            let nextVC = storyboard.instantiateViewController(withIdentifier: "GUIViewController") as! GUIViewController
            nextVC.viewModel = self.model
            nextVC.delegate = self
            vc = nextVC
            
        case .result:
            let nextVC = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as! ResultViewController
            nextVC.viewModel = self.model
            nextVC.delegate = self
            vc = nextVC
        }
        
        
        if let progressVC = vc as? (UIViewController & IdentificationProgressUpdatable),
           let idx = progressSteps.firstIndex(of: step) {
            
            progressVC.loadViewIfNeeded()
            
            let completed = idx + 1
            progressVC.updateProgress(current: completed, total: progressSteps.count)

        }
        
        self.navigationController?.pushViewController(vc, animated: false)
    }
    
    
    func handleShapeStepCompletion() {
        
        let fieldMarksSelected = model.fieldMarkOptions.contains {
            $0.fieldMarkName == .fieldMarks && ($0.isSelected ?? false)
        }
        
        let isLastDecisionStep = !flowSteps.contains(.fieldMarks) && !flowSteps.contains(.gui)
        
        if fieldMarksSelected,
           let nextIndex = flowSteps.firstIndex(of: .fieldMarks) {
            
            currentStepIndex = nextIndex
            return
        }
        
        if isLastDecisionStep,
           let resIndex = flowSteps.firstIndex(of: .result) {
            
            currentStepIndex = resIndex
            return
        }
        
       
    }
}
extension IdentificationViewController: IdentificationFlowStepDelegate {
    func didFinishStep() {
    
        if let visibleVC = navigationController?.topViewController {
            
            
            let currentStep: IdentificationStep?
            if visibleVC is DateandLocationViewController {
                currentStep = .dateLocation
            } else if visibleVC is IdentificationSizeViewController {
                currentStep = .size
            } else if visibleVC is IdentificationShapeViewController {
                currentStep = .shape
            } else if visibleVC is IdentificationFieldMarksViewController {
                currentStep = .fieldMarks
            } else if visibleVC is GUIViewController {
                currentStep = .gui
            } else {
                currentStep = nil
            }
            
            
            if let currentStep = currentStep,
               let indexInFlow = flowSteps.firstIndex(of: currentStep) {
                currentStepIndex = indexInFlow + 1
            }
        }
        
        
        pushNextViewController()
    }
    
    func didTapShapes() {
        handleShapeStepCompletion()
        pushNextViewController()
    }
    
    func didTapLeftButton() {
        
        navigationController?.popToRootViewController(animated: true)
    }
    
    func openMapScreen() {
        
        let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
}


