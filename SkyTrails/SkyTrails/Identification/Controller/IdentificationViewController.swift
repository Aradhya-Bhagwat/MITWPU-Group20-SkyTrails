//
//  IdentificationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit
import SwiftData


struct IdentificationOption {
    let category: FilterCategory
    var isSelected: Bool
}

class IdentificationViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate {
    
    private var flowSteps: [IdentificationStep] = []
    private var currentStepIndex: Int = 0
    private var progressSteps: [IdentificationStep] = []
    
    // Local state for UI
    private var isSeeding = false
    private var options: [IdentificationOption] = []
    private var histories: [IdentificationSession] = []
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var historyCollectionView: UICollectionView!
    @IBOutlet weak var historyCollectionHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var warningLabel: UILabel!
    
    // Updated to Implicitly Unwrapped Optional because it requires context to init
    var model: IdentificationManager!
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        applyTableContainerShadow(to: containerView)
        updateSelectionState()
        updateHistoryCollectionHeight()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh history when view appears (in case new sessions were saved)
        fetchHistory()
        updateHistoryInteraction()
        tableView.reloadData()
        historyCollectionView.reloadData()
        scheduleHistoryCollectionHeightUpdate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        
        // Initialize SwiftData and Manager
        setupModel()
        
        // Initialize Options based on FilterCategory enum
        setupOptions()
        
        // Fetch initial history
        fetchHistory()
        
        let nib = UINib(nibName: "HistoryCollectionViewCell", bundle: nil)
        historyCollectionView.register(nib, forCellWithReuseIdentifier: "history_cell")
        
        updateHistoryInteraction()
        
        navigationController?.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        historyCollectionView.delegate = self
        historyCollectionView.dataSource = self
        historyCollectionView.isScrollEnabled = false
        
        applyTableAppearance()
        setupHistoryFlowLayout()
        
        tableView.reloadData()
        historyCollectionView.reloadData()
        scheduleHistoryCollectionHeightUpdate()
        updateSelectionState()
    }

    private func handleUserInterfaceStyleChange() {
        applyTableAppearance()
        applyTableContainerShadow(to: containerView)
        updateSelectionState()
        tableView.reloadData()
        historyCollectionView.reloadData()
        scheduleHistoryCollectionHeightUpdate()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }
    
    public func resetIdentificationOptions() {
        setupOptions()
        tableView.reloadData()
        updateSelectionState()
    }
    
    private func setupModel() {
        // Use the shared context from WatchlistManager to avoid store conflicts
        let context = WatchlistManager.shared.context
        self.model = IdentificationManager(modelContext: context)

        do {
            // Seed data if the database is empty
            let birdCount = try context.fetchCount(FetchDescriptor<Bird>())
            let shapeCount = try context.fetchCount(FetchDescriptor<BirdShape>())
            let fieldMarkCount = try context.fetchCount(FetchDescriptor<BirdFieldMark>())
            let variantCount = try context.fetchCount(FetchDescriptor<FieldMarkVariant>())
            let identificationBirdCount = try context.fetchCount(
                FetchDescriptor<Bird>(predicate: #Predicate<Bird> { bird in
                    bird.shape_id != nil && bird.size_category != nil
                })
            )
            print("DEBUG: Seed check counts -> birds: \(birdCount), shapes: \(shapeCount)")
            if birdCount > 0 && shapeCount == 0 {
                print("WARNING: Birds exist but shapes are missing. IdentificationSeeder may be skipped.")
            }
            let needsSeeding = shapeCount == 0 || fieldMarkCount == 0 || variantCount == 0 || identificationBirdCount == 0
            if needsSeeding {
                isSeeding = true
                updateSelectionState() // Disable button while seeding
                Task { @MainActor in
                    do {
                        try IdentificationSeeder.shared.seed(context: context)
                        // Must re-fetch shapes after seeding
                        self.model.fetchShapes()
                        self.isSeeding = false
                        self.updateSelectionState() // Re-enable button
                        self.tableView.reloadData()
                    } catch {
                        print("Error seeding database: \(error)")
                        self.isSeeding = false
                        self.updateSelectionState()
                    }
                }
            }
        } catch {
            print("Failed to access SwiftData context: \(error)")
        }
    }
    
    private func setupOptions() {
        // Map FilterCategory cases to local options
        self.options = FilterCategory.allCases.map { category in
            IdentificationOption(category: category, isSelected: false)
        }
    }

    private func applyOptionsFromSession(_ session: IdentificationSession) {
        let saved = session.selectedFilterCategories ?? []
        if !saved.isEmpty {
            let savedSet = Set(saved)
            options = FilterCategory.allCases.map { category in
                IdentificationOption(category: category, isSelected: savedSet.contains(category.rawValue))
            }
            return
        }

        options = FilterCategory.allCases.map { category in
            let isSelected: Bool
            switch category {
            case .locationDate:
                isSelected = session.locationId != nil
            case .size:
                isSelected = session.sizeCategory != nil
            case .shape:
                isSelected = session.shape != nil
            case .fieldMarks:
                isSelected = !(session.selectedMarks?.isEmpty ?? true)
            }
            return IdentificationOption(category: category, isSelected: isSelected)
        }
    }

    private func deselectShapeForReloadKeepingSavedShape() {
        if let shapeIndex = options.firstIndex(where: { $0.category == .shape }) {
            options[shapeIndex].isSelected = false
        }

        // Keep model.selectedShape as-is; only remove Shape from menu flow options.
        model.selectedMenuOptionRawValues = options
            .filter { $0.isSelected }
            .map { $0.category.rawValue }
    }
    
    private func fetchHistory() {
        let context = WatchlistManager.shared.context
            
           
        do {
            let descriptor = FetchDescriptor<IdentificationSession>(
                sortBy: [SortDescriptor(\.observationDate, order: .reverse)]
            )
            let sessions = try context.fetch(descriptor)
            self.histories = sessions.filter { $0.status == .completed }
        } catch {
            print("Error fetching history: \(error)")
            self.histories = []
        }
    }
    
    func updateSelectionState() {
        let selectedCount = options.filter { $0.isSelected }.count
        let isValid = selectedCount >= 2 && !isSeeding
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        warningLabel.isHidden = isValid
        startButton.isEnabled = isValid
        
        let titleColor: UIColor = isValid ? .label : .systemGray3
        let shadowOpacity: Float = isValid ? 0.12 : 0.06
        let shadowRadius: CGFloat = isValid ? 7 : 4
        let shadowOffset = CGSize(width: 0, height: isValid ? 3 : 2)
        
        startButton.setTitleColor(titleColor, for: .normal)
        startButton.layer.cornerRadius = 16
        startButton.backgroundColor = isDarkMode ? .secondarySystemBackground : .systemBackground
        startButton.layer.masksToBounds = false

        if isDarkMode {
            startButton.layer.shadowOpacity = 0
            startButton.layer.shadowRadius = 0
            startButton.layer.shadowOffset = .zero
            startButton.layer.shadowPath = nil
        } else {
            startButton.layer.shadowColor = UIColor.black.cgColor
            startButton.layer.shadowOpacity = shadowOpacity
            startButton.layer.shadowRadius = shadowRadius
            startButton.layer.shadowOffset = shadowOffset
            startButton.layer.shadowPath = UIBezierPath(
                roundedRect: startButton.bounds,
                cornerRadius: startButton.layer.cornerRadius
            ).cgPath
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(histories.count, 1)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let historyCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "history_cell",
            for: indexPath
        ) as! HistoryCollectionViewCell
        
        if histories.isEmpty {
            historyCell.showEmptyState()
        } else {
            let historyItem = histories[indexPath.row]
            historyCell.configureCell(historyItem: historyItem)
        }
        applyHistoryCardAppearance(to: historyCell)
        
        return historyCell
    }
    
    private func updateHistoryInteraction() {
        let isEmpty = histories.isEmpty
        
        historyCollectionView.isUserInteractionEnabled = !isEmpty
        historyCollectionView.alpha = isEmpty ? 0.6 : 1.0
    }

    private func applyTableAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let tableCardColor = isDarkMode
            ? UIColor.secondarySystemBackground
            : UIColor.systemBackground

        tableView.backgroundColor = tableCardColor
        tableView.separatorColor = isDarkMode
            ? UIColor.systemGray3.withAlphaComponent(0.45)
            : UIColor.systemGray4.withAlphaComponent(0.6)
    }

    private func applyHistoryCardAppearance(to cell: UICollectionViewCell) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardSurfaceColor: UIColor = .secondarySystemBackground
        cell.layer.masksToBounds = false
        cell.layer.cornerRadius = 16
        cell.contentView.layer.cornerRadius = 16
        cell.contentView.clipsToBounds = true
        cell.contentView.backgroundColor = cardSurfaceColor

        if let historyCell = cell as? HistoryCollectionViewCell {
            historyCell.containeView.layer.cornerRadius = 16
            historyCell.containeView.layer.masksToBounds = true
            historyCell.containeView.backgroundColor = cardSurfaceColor
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
    
 
    
    private func applyTableContainerShadow(to view: UIView) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let tableCardColor = isDarkMode
            ? UIColor.secondarySystemBackground
            : UIColor.systemBackground
        
        view.layer.cornerRadius = 16
        view.backgroundColor = tableCardColor
        view.layer.masksToBounds = false

        if isDarkMode {
            view.layer.shadowOpacity = 0
            view.layer.shadowRadius = 0
            view.layer.shadowOffset = .zero
            view.layer.shadowPath = nil
        } else {
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.09
            view.layer.shadowOffset = CGSize(width: 0, height: 3)
            view.layer.shadowRadius = 7
            view.layer.shadowPath = UIBezierPath(
                roundedRect: view.bounds,
                cornerRadius: view.layer.cornerRadius
            ).cgPath
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
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
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let rowColor = isDarkMode
            ? UIColor.secondarySystemBackground
            : UIColor.systemBackground
        
        let item = options[indexPath.row]
        cell.textLabel?.text = item.category.rawValue // Using rawValue from FilterCategory
        cell.textLabel?.textColor = .label
        cell.backgroundColor = rowColor
        cell.contentView.backgroundColor = rowColor
        cell.tintColor = .systemBlue

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = UIColor.systemBlue.withAlphaComponent(isDarkMode ? 0.24 : 0.10)
        cell.selectedBackgroundView = selectedBackgroundView
        
        // Using icon property from FilterCategory
        if let img = UIImage(named: item.category.icon) {
            
            let targetSize = CGSize(width: 28, height: 28)
            let resized = resize(img, to: targetSize).withRenderingMode(.alwaysTemplate)
            cell.imageView?.image = resized
            cell.imageView?.contentMode = .scaleAspectFit
            cell.imageView?.frame = CGRect(origin: .zero, size: targetSize)
            cell.imageView?.tintColor = .label
        } else {
            cell.imageView?.image = UIImage(systemName: "questionmark.circle")?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = .systemGray
        }
        
        cell.accessoryType = item.isSelected ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let currentState = options[indexPath.row].isSelected
        options[indexPath.row].isSelected = !currentState

        let tappedCategory = options[indexPath.row].category
        let isNowSelected = options[indexPath.row].isSelected

        // If Field Marks selected → auto-select Shape (dependency)
        if tappedCategory == .fieldMarks && isNowSelected {
            if let shapeIndex = options.firstIndex(where: { $0.category == .shape }) {
                options[shapeIndex].isSelected = true
            }
        }

        // If Shape deselected → also deselect Field Marks (cascade)
        if tappedCategory == .shape && !isNowSelected {
            if let fieldMarksIndex = options.firstIndex(where: { $0.category == .fieldMarks }) {
                options[fieldMarksIndex].isSelected = false
            }
        }

        tableView.reloadData()
        updateSelectionState()
    }
    private func setupHistoryFlowLayout() {
        guard let layout = historyCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }

    private func scheduleHistoryCollectionHeightUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.updateHistoryCollectionHeight()
        }
    }

    private func updateHistoryCollectionHeight() {
        historyCollectionView.layoutIfNeeded()
        let contentHeight = historyCollectionView.collectionViewLayout.collectionViewContentSize.height
        let newHeight = max(contentHeight, 1)
        if abs(historyCollectionHeightConstraint.constant - newHeight) > 0.5 {
            historyCollectionHeightConstraint.constant = newHeight
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let minItemWidth: CGFloat = 160
        let maxItemsPerRow: CGFloat = 4
        let interItemSpacing: CGFloat = 16
        let sectionInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        let availableWidth = collectionView.bounds.width - sectionInsets.left - sectionInsets.right
        

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
            if itemsPerRow == 0 {
                itemsPerRow = 1
                break
            }
        }
        
        if itemsPerRow < 1 { itemsPerRow = 1 }
        if itemsPerRow > maxItemsPerRow { itemsPerRow = maxItemsPerRow }
        
        let actualTotalSpacing = interItemSpacing * (itemsPerRow - 1)
        let itemWidth = (availableWidth - actualTotalSpacing) / itemsPerRow
      
        let imageHorizontalMargins: CGFloat = 16
        let imageWidth = itemWidth - imageHorizontalMargins
        let imageHeight = imageWidth * (3.0 / 4.0)

        // Match vertical spacing to HistoryCollectionViewCell.xib.
        let topMargin: CGFloat = 8
        let imageToLabelSpacing: CGFloat = 6
        let labelSpacing: CGFloat = 2
        let bottomMargin: CGFloat = 8

        let speciesText: String
        if histories.isEmpty {
            speciesText = "No history yet"
        } else {
            speciesText = histories[indexPath.row].result?.bird?.commonName ?? "Unknown Species"
        }

        let speciesFont = UIFont.systemFont(ofSize: 15)
        let maxSpeciesLabelHeight = ceil(speciesFont.lineHeight * 2)
        let measuredSpeciesHeight = ceil(
            (speciesText as NSString).boundingRect(
                with: CGSize(width: imageWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: speciesFont],
                context: nil
            ).height
        )
        let speciesLabelHeight = min(maxSpeciesLabelHeight, measuredSpeciesHeight)
        let dateLabelHeight = ceil(UIFont.systemFont(ofSize: 13).lineHeight)

        let totalHeight = topMargin +
                         imageHeight +
                         imageToLabelSpacing +
                         speciesLabelHeight +
                         labelSpacing +
                         dateLabelHeight +
                         bottomMargin
        
        return CGSize(width: itemWidth, height: totalHeight)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self, self.historyCollectionView != nil else { return }
            self.historyCollectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.scheduleHistoryCollectionHeightUpdate()
        }
    }
    
    @IBAction func startButtonTapped(_ sender: UIButton) {
        model.reset()
        model.isReloadFlowActive = false
        model.selectedMenuOptionRawValues = options
            .filter { $0.isSelected }
            .map { $0.category.rawValue }
        startIdentificationFlow(from: self.options)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !histories.isEmpty else { return }
        let selectedSession = histories[indexPath.row]
        
        applyOptionsFromSession(selectedSession)
        model.selectedMenuOptionRawValues = options
            .filter { $0.isSelected }
            .map { $0.category.rawValue }
        model.isReloadFlowActive = false
        model.loadSessionAndFilter(session: selectedSession)
        
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        if let resultVC = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as? ResultViewController {
            resultVC.viewModel = self.model
            resultVC.delegate = self
            resultVC.historyItem = selectedSession.result
            self.navigationController?.pushViewController(resultVC, animated: true)
        }
    }
    func startIdentificationFlow(from options: [IdentificationOption]) {
        flowSteps.removeAll()
        
        let selected = options.filter { $0.isSelected }
        for option in selected {
            // Map FilterCategory to IdentificationStep
            switch option.category {
            case .locationDate: flowSteps.append(.dateLocation)
            case .size:         flowSteps.append(.size)
            case .shape:        flowSteps.append(.shape)
            case .fieldMarks:   flowSteps.append(.fieldMarks)
            }
        }
        
        if selected.contains(where: { $0.category == .fieldMarks }) {
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
            // Updated: Manager uses `allShapes`, not `birdShapes`
            nextVC.filteredShapes = model.allShapes
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
        
        let fieldMarksSelected = options.contains {
            $0.category == .fieldMarks && $0.isSelected
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
        if let session = model.currentSession {
            applyOptionsFromSession(session)
            deselectShapeForReloadKeepingSavedShape()
            model.isReloadFlowActive = true
            updateSelectionState()
            tableView.reloadData()
            navigationController?.popToRootViewController(animated: false)
            startIdentificationFlow(from: self.options)
            return
        }

        // Reload in an active new flow should preserve the user's current selections
        // (shape/size/location/fieldmarks) instead of returning to an empty root screen.
        let hasActiveFlowState =
            model.selectedShape != nil ||
            model.selectedSizeCategory != nil ||
            model.selectedLocation != nil ||
            !model.selectedFieldMarks.isEmpty ||
            !model.tempSelectedAreas.isEmpty ||
            !model.results.isEmpty

        if hasActiveFlowState {
            deselectShapeForReloadKeepingSavedShape()
            model.isReloadFlowActive = true
            updateSelectionState()
            tableView.reloadData()
            navigationController?.popToRootViewController(animated: false)
            startIdentificationFlow(from: self.options)
            return
        }

        navigationController?.popToRootViewController(animated: true)
    }
    
    func openMapScreen() {
        
        let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
}
