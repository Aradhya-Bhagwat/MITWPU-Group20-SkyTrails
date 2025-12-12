//
//  PredictOutputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

// PredictOutputViewController.swift

import UIKit
import CoreLocation

class PredictOutputViewController: UIViewController {
    
    // Data passed from PredictMapViewController
    var predictions: [FinalPredictionResult] = []
    var inputData: [PredictionInputData] = []
    
    // UI Elements
    private let tableView = UITableView()
    
    // Group predictions by the input card they matched for structured display
    private var groupedPredictions: [String: [FinalPredictionResult]] = [:]

    var predictions: [FinalPredictionResult] = []
    var inputData: [PredictionInputData] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupNavigation()
        setupTableView()
        processData()
    }
    
    private func setupNavigation() {
        // Title
        navigationItem.title = "Prediction Results"
        
        // Redo Button (Top Left)
        let redoButton = UIBarButtonItem(title: "Redo", style: .plain, target: self, action: #selector(didTapRedo))
        navigationItem.leftBarButtonItem = redoButton
        
        // Home Button (Top Right)
        let homeButton = UIBarButtonItem(image: UIImage(systemName: "house"), style: .plain, target: self, action: #selector(didTapHome))
        navigationItem.rightBarButtonItem = homeButton
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.rowHeight = 80 // Fixed height for bird cell
        tableView.register(BirdResultCell.self, forCellReuseIdentifier: "BirdResultCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func processData() {
        // Group predictions by the location name of the input card
        for prediction in predictions {
            let inputIndex = prediction.matchedInputIndex
            let locationName = inputData[inputIndex].locationName ?? "Input \(inputIndex + 1)"
            
            if groupedPredictions[locationName] == nil {
                groupedPredictions[locationName] = []
            }
            groupedPredictions[locationName]?.append(prediction)
        }
        tableView.reloadData()
    }
    
    // MARK: - Navigation Actions
    
    @objc private func didTapRedo() {
        // This dismisses the output VC and returns to the PredictInputViewController
        // Assuming PredictOutputViewController is embedded in a Nav Controller:
        self.navigationController?.popViewController(animated: true)
        
        // If it's the root of the modal swap, we need the map VC to revert the swap.
        // For simplicity, let's assume the user taps "Redo" on the Output VC, and we need to go back to the Input VC state.
        // Since we did a child view controller swap, reversing this is complex.
        // A simple solution for MVP: just ask the mapVC to load the Input VC again.
        if let mapVC = self.parent as? PredictMapViewController {
            // mapVC.revertToInputScreen(with: inputData) // (Requires new function in MapVC)
            
            // For now, let the user manually drag the modal up or start a new prediction
            // Or, simply dismiss the entire modal flow:
            // self.dismiss(animated: true, completion: nil)
            print("TODO: Implement Redo/Revert logic on PredictMapViewController.")
        }
    }
    
    @objc private func didTapHome() {
        // Dismiss the entire prediction modal flow
        self.parent?.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Table View Data Source and Delegate

extension PredictOutputViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return groupedPredictions.keys.count // One section per input location
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let keys = groupedPredictions.keys.sorted() // Ensure stable order
        return keys[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let keys = groupedPredictions.keys.sorted()
        let locationName = keys[section]
        return groupedPredictions[locationName]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdResultCell", for: indexPath) as? BirdResultCell else {
            return UITableViewCell()
        }
        
        let keys = groupedPredictions.keys.sorted()
        let locationName = keys[indexPath.section]
        
        if let prediction = groupedPredictions[locationName]?[indexPath.row] {
            cell.configure(with: prediction.birdName, imageName: prediction.imageName)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .label
            header.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        }
    }
}

// MARK: - Custom Cell (Must be defined separately, or in the same file for quick testing)

class BirdResultCell: UITableViewCell {
    
    private let birdImageView = UIImageView()
    private let birdNameLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Setup Image View
        birdImageView.translatesAutoresizingMaskIntoConstraints = false
        birdImageView.contentMode = .scaleAspectFit
        birdImageView.clipsToBounds = true
        
        // Setup Label
        birdNameLabel.translatesAutoresizingMaskIntoConstraints = false
        birdNameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        
        contentView.addSubview(birdImageView)
        contentView.addSubview(birdNameLabel)
        
        NSLayoutConstraint.activate([
            // Image Constraints
            birdImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            birdImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 60),
            birdImageView.heightAnchor.constraint(equalToConstant: 60),
            
            // Label Constraints
            birdNameLabel.leadingAnchor.constraint(equalTo: birdImageView.trailingAnchor, constant: 16),
            birdNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            birdNameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with name: String, imageName: String) {
        birdNameLabel.text = name
        // ⭐️ IMPORTANT: This relies on having images with these names in your Assets catalog
        birdImageView.image = UIImage(named: imageName) ?? UIImage(systemName: "photo")
    }
}
