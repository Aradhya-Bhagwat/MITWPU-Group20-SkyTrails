//
//  IdentificationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class IdentificationViewController: UIViewController, UITableViewDelegate,UITableViewDataSource,UICollectionViewDataSource,UICollectionViewDelegate{
    
    private var flowSteps: [IdentificationStep] = []
    private var currentStepIndex: Int = 0
    private var progressSteps: [IdentificationStep] = []
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var collectionView: UICollectionView!
 
    var model: IdentificationModels = IdentificationModels()


    var history: [History] = []
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Apply shadow after the button has its final frame for correct corner radius
        applyCardShadow(to: startButton)
        startButton.layer.shadowPath = UIBezierPath(roundedRect: startButton.bounds, cornerRadius: 12).cgPath
    }
    override func viewDidLoad() {
        super.viewDidLoad()
       

        tableView.delegate = self
        tableView.dataSource = self

        startButton.backgroundColor = .white
        startButton.setTitleColor(.black, for: .normal)
        startButton.tintColor = .white
      startButton.adjustsImageWhenHighlighted = false
        

       
        tableView.rowHeight = 56
    
        applyCardShadow(to: tableView)

        let layout = generateLayout()
        collectionView.setCollectionViewLayout(layout, animated: true)
        collectionView.dataSource = self
        collectionView.delegate = self
        history = model.histories

      

  }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(history.count, 1)

    }

    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "history_cell", for: indexPath)
        
        guard let historyCell = cell as? IdentificationHistoryCollectionViewCell else {
              return cell
          }

        if history.isEmpty {
            // IMAGE
            historyCell.historyImageView.image = UIImage(systemName: "clock.arrow.circlepath")
            historyCell.historyImageView.tintColor = .lightGray
            historyCell.historyImageView.contentMode = .scaleAspectFit
            
            // TEXT
            historyCell.specieNameLabel.text = "No history yet"
            historyCell.specieNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            historyCell.specieNameLabel.textAlignment = .center
            historyCell.specieNameLabel.textColor = .darkGray
            
            historyCell.dateLabel.text = "Start identifying birds!"
            historyCell.dateLabel.font = UIFont.systemFont(ofSize: 14)
            historyCell.dateLabel.textAlignment = .center
            historyCell.dateLabel.textColor = .lightGray
            historyCell.layer.shadowOpacity = 0

            return historyCell
        }

        let historyItems = history[indexPath.row]
        historyCell.configureCell(historyItem: historyItems)

        historyCell.layer.backgroundColor = UIColor.white.cgColor
        historyCell.layer.cornerRadius = 12
        historyCell.layer.shadowColor = UIColor.black.cgColor
        historyCell.layer.shadowOpacity = 0.1
        historyCell.layer.shadowOffset = CGSize(width: 0, height: 2)
        historyCell.layer.shadowRadius = 8
        historyCell.layer.masksToBounds = false
        
        return historyCell
    }
    

    func applyCardShadow(to view: UIView) {
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.masksToBounds = false
        view.layer.backgroundColor = UIColor.white.cgColor
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
        cell.textLabel?.text = item.fieldMarkName
      
        if let img = UIImage(named: item.symbols) {
    
            let targetSize = CGSize(width: 28, height: 28) // Restore the target size
            let resized = resize(img, to: targetSize)
            cell.imageView?.image = resized
            cell.imageView?.contentMode = .scaleAspectFit // Use ScaleAspectFit for icons
            cell.imageView?.frame = CGRect(origin: .zero, size: targetSize) // Explicitly set frame
            cell.imageView?.tintColor = .label // Keep tint color for SF Symbols if they are being used.
        } else {
            // Fallback for debugging, keep this.
            cell.imageView?.image = UIImage(systemName: "questionmark.circle")
            cell.imageView?.tintColor = .systemGray
        }
        
        cell.accessoryType = (item.isSelected ?? false) ? .checkmark : .none

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        model.fieldMarkOptions[indexPath.row].isSelected = !(model.fieldMarkOptions[indexPath.row].isSelected ?? false)

        tableView.reloadRows(at: [indexPath], with: .none)

    }
    
    func generateLayout() -> UICollectionViewLayout {
        let size  = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .estimated(200))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(10)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }

    @IBAction func startButtonTapped(_ sender: UIButton) {
      

        let selected = model.fieldMarkOptions.filter { $0.isSelected ?? false }


        if selected.count < 2 {
            let alert = UIAlertController(
                title: "Select at least two",
                message: "Please choose at least two identification methods to continue.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

//        coordinator?.configureSteps(from: viewModel.fieldMarkOptions)
        startIdentificationFlow(from: model.fieldMarkOptions)
    }
//    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        // Prevent action on the "Empty State" placeholder cell
//        guard !history.isEmpty else { return }
//        
//        let selectedHistory = history[indexPath.row]
//        coordinator?.goDirectlyToResult(fromHistory: selectedHistory, index: indexPath.row)
//        }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard !history.isEmpty else { return }
            let selectedHistory = history[indexPath.row]
    
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
            
            // 1. Filter selected options to build the step list
            let selected = options.filter { $0.isSelected ?? false }
            for option in selected {
                switch option.fieldMarkName {
                case "Location & Date": flowSteps.append(.dateLocation)
                case "Size":            flowSteps.append(.size)
                case "Shape":           flowSteps.append(.shape)
                case "Field Marks":     flowSteps.append(.fieldMarks)
                default: break
                }
            }
            
            // Logic for GUI step
            if selected.contains(where: { $0.fieldMarkName == "Field Marks" }) {
                flowSteps.append(.gui)
            }
            
            flowSteps.append(.result)
            
            // Calculate progress steps (exclude result/gui for progress bar logic)
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
                // Flow finished, maybe reset?
                return
            }
            
            let step = flowSteps[currentStepIndex]
            currentStepIndex += 1 // Increment for next time
            
            let storyboard = UIStoryboard(name: "Identification", bundle: nil)
            let vc: UIViewController
            
            switch step {
            case .dateLocation:
                let nextVC = storyboard.instantiateViewController(withIdentifier: "DateandLocationViewController") as! DateandLocationViewController
                nextVC.viewModel = self.model
                nextVC.delegate = self // MVC: WE are the delegate now
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
                // Note: If you have a filteredShapes property, pass it here:
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
            
            // Progress Bar Logic
            if let progressVC = vc as? (UIViewController & IdentificationProgressUpdatable),
                   let idx = progressSteps.firstIndex(of: step) {
                    
                    // ADD THIS LINE: Force the view to load so outlets are not nil
                    progressVC.loadViewIfNeeded()
                    
                    progressVC.updateProgress(current: idx + 1, total: progressSteps.count)
                }

                self.navigationController?.pushViewController(vc, animated: true)
        }

        // Specialized Logic from Coordinator (didTapShape)
        func handleShapeStepCompletion() {
            let fieldMarksSelected = model.fieldMarkOptions.contains {
                $0.fieldMarkName == "Field Marks" && ($0.isSelected ?? false)
            }
            
            let isLastDecisionStep = !flowSteps.contains(.fieldMarks) && !flowSteps.contains(.gui)

            if fieldMarksSelected {
                // Jump to FieldMarks if it exists
                if let nextIndex = flowSteps.firstIndex(of: .fieldMarks) {
                    currentStepIndex = nextIndex
                    pushNextViewController()
                }
            } else if isLastDecisionStep {
                // Jump to Result
                if let resIndex = flowSteps.firstIndex(of: .result) {
                    currentStepIndex = resIndex
                    pushNextViewController()
                }
            } else {
                pushNextViewController()
            }
        }
    }

extension IdentificationViewController: IdentificationFlowStepDelegate {
    func didFinishStep() {
        pushNextViewController()
    }
    
    func didTapShapes() {
        handleShapeStepCompletion()
    }
    
    func didTapLeftButton() {
        // Reset or Pop
        navigationController?.popToRootViewController(animated: true)
    }
    
    func openMapScreen() {
        // MVC style map opening
        let storyboard = UIStoryboard(name: "SharedStoryboard", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
             // mapVC.delegate = self (if needed)
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
}


