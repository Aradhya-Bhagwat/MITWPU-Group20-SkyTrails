//
//  BirdDateInputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

struct BirdDateInput {
    let species: SpeciesData
    var startDate: Date?
    var endDate: Date?
}

class BirdDateInputViewController: UIViewController {

    // MARK: - Data
    var speciesList: [SpeciesData] = []
    var currentIndex: Int = 0
    var collectedData: [BirdDateInput] = []
    
    // Local state for the current bird
    private var currentStartDate: Date = Date()
    private var currentEndDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    
    // MARK: - UI Elements
    private let imageView = UIImageView()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        
        print("📝 Wizard Step \(currentIndex + 1)/\(speciesList.count): Configuring for \(speciesList[currentIndex].name)")
        if !collectedData.isEmpty {
            print("   ↳ Previous collected data count: \(collectedData.count)")
        }
        
        setupNavigationBar()
        setupUI()
        loadCurrentBird()
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        // Right: Next (or Done) and Delete
        let nextTitle = (currentIndex == speciesList.count - 1) ? "Done" : "Next"
        let nextButton = UIBarButtonItem(title: nextTitle, style: .done, target: self, action: #selector(didTapNext))
        
        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didTapDelete))
        
        navigationItem.rightBarButtonItems = [nextButton, deleteButton]
    }
    
    private func setupUI() {
        // 1. Image View (Middle Aligned)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .systemGray6
        
        view.addSubview(imageView)
        
        // 2. Table View
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DateCell")
        tableView.isScrollEnabled = false // It's just 2 rows, keep it static
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            // Image: Centered horizontally, Top margin
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // REVERSED DIMENSIONS: Width 240, Height 160 (Landscape-ish)
            imageView.widthAnchor.constraint(equalToConstant: 240),
            imageView.heightAnchor.constraint(equalToConstant: 160),
            
            // Table: Below Image, fill rest
            tableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadCurrentBird() {
        guard currentIndex < speciesList.count else { return }
        let bird = speciesList[currentIndex]
        
        self.title = bird.name
        imageView.image = UIImage(named: bird.imageName)
        
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func didTapNext() {
        let bird = speciesList[currentIndex]
        let input = BirdDateInput(species: bird, startDate: currentStartDate, endDate: currentEndDate)
        
        print("✅ Saving input for \(bird.name): \(currentStartDate) to \(currentEndDate)")
        
        // Append to our collection
        var newCollection = collectedData
        newCollection.append(input)
        
        if currentIndex < speciesList.count - 1 {
            // Go to Next Bird
            let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
            guard let nextVC = storyboard.instantiateViewController(withIdentifier: "BirdDateInputViewController") as? BirdDateInputViewController else { return }
            
            nextVC.speciesList = self.speciesList
            nextVC.currentIndex = self.currentIndex + 1
            nextVC.collectedData = newCollection
            
            navigationController?.pushViewController(nextVC, animated: true)
            
        } else {
            // Finished! Go to Map
            print("🚀 Wizard Complete. Passing \(newCollection.count) inputs to Map.")
            let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
            guard let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController else { return }
            
            mapVC.predictionInputs = newCollection
            
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    @objc private func didTapDelete() {
        print("🗑️ Delete requested for \(speciesList[currentIndex].name). Current collected data: \(collectedData.count)")
        
        // We create a NEW list without this bird
        var newSpeciesList = speciesList
        newSpeciesList.remove(at: currentIndex)
        
        if newSpeciesList.isEmpty {
            // Nothing left, go back to selection
            print("   ↳ List empty. Returning to root.")
            navigationController?.popToRootViewController(animated: true)
            return
        }
        
        if currentIndex < newSpeciesList.count {
            // Case: We deleted a bird in the middle or start.
            // The 'currentIndex' now points to the *next* bird in the shifted array.
            // We push a new VC for that next bird.
            
            let nextBird = newSpeciesList[currentIndex]
            print("   ↳ Moving to next bird: \(nextBird.name)")
            
            let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
            guard let nextVC = storyboard.instantiateViewController(withIdentifier: "BirdDateInputViewController") as? BirdDateInputViewController else { return }
            
            nextVC.speciesList = newSpeciesList
            nextVC.currentIndex = currentIndex
            nextVC.collectedData = collectedData // Pass existing data, do NOT add current
            
            navigationController?.pushViewController(nextVC, animated: true)
            
        } else {
            // Case: We deleted the *last* bird in the list.
            // We should either finish (if we have data) or go back.
            
            if !collectedData.isEmpty {
                print("   ↳ Deleted last item. Finishing with \(collectedData.count) previous inputs.")
                let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
                guard let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController else { return }
                mapVC.predictionInputs = collectedData
                navigationController?.pushViewController(mapVC, animated: true)
            } else {
                print("   ↳ Deleted last item and no previous data. Returning to root.")
                navigationController?.popToRootViewController(animated: true)
            }
        }
    }
    
    @objc private func startDateChanged(_ sender: UIDatePicker) {
        currentStartDate = sender.date
    }
    
    @objc private func endDateChanged(_ sender: UIDatePicker) {
        currentEndDate = sender.date
    }
}

extension BirdDateInputViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2 // Start, End
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "DateCell")
        cell.selectionStyle = .none
        
        // Setup Date Picker
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        
        // Add row label
        if indexPath.row == 0 {
            cell.textLabel?.text = "Start Date"
            datePicker.date = currentStartDate
            datePicker.addTarget(self, action: #selector(startDateChanged(_:)), for: .valueChanged)
        } else {
            cell.textLabel?.text = "End Date"
            datePicker.date = currentEndDate
            datePicker.addTarget(self, action: #selector(endDateChanged(_:)), for: .valueChanged)
        }
        
        // Use accessoryView for the picker
        cell.accessoryView = datePicker
        
        return cell
    }
}