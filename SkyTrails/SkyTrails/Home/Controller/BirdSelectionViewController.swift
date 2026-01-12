//
//  BirdSelectionViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class BirdSelectionViewController: UIViewController {

    var allSpecies: [SpeciesData] = []
    var selectedSpecies: Set<String> = []
    var existingInputs: [BirdDateInput] = []
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Select Species"
        self.view.backgroundColor = .systemBackground
        setupTableView()
        setupNavigationBar()
        
        if allSpecies.isEmpty {
            if let speciesData = HomeManager.shared.predictionData?.speciesData {
                self.allSpecies = speciesData
            }
        }
    }
    
    private func setupNavigationBar() {

        let nextButton = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(didTapNext))
        navigationItem.rightBarButtonItem = nextButton
        
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BirdCell")
        tableView.allowsMultipleSelection = true
        tableView.tableFooterView = UIView()
    }
    
    @objc private func didTapNext() {

        let selectedObjects = allSpecies.filter { selectedSpecies.contains($0.id) }
        
        guard !selectedObjects.isEmpty else {
            let alert = UIAlertController(title: "No Selection", message: "Please select at least one bird.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        

        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        guard let dateInputVC = storyboard.instantiateViewController(withIdentifier: "BirdDateInputViewController") as? BirdDateInputViewController else { return }
        
        dateInputVC.speciesList = selectedObjects
        dateInputVC.currentIndex = 0
        
        var newCollectedData: [BirdDateInput] = []
        for species in selectedObjects {
            if let existing = existingInputs.first(where: { $0.species.id == species.id }) {
                newCollectedData.append(existing)
            } else {
                let start = Date()
                let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
                newCollectedData.append(BirdDateInput(species: species, startDate: start, endDate: end))
            }
        }
        dateInputVC.collectedData = newCollectedData
        
        navigationController?.pushViewController(dateInputVC, animated: true)
    }
}

extension BirdSelectionViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allSpecies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BirdCell", for: indexPath)
        let species = allSpecies[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = species.name
        content.image = UIImage(named: species.imageName)
        
        
        let imageSize = CGSize(width: 40, height: 40)
        content.imageProperties.maximumSize = imageSize
        content.imageProperties.cornerRadius = 4
        
        
        cell.contentConfiguration = content
        
        if selectedSpecies.contains(species.id) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let species = allSpecies[indexPath.row]
        selectedSpecies.insert(species.id)
        
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let species = allSpecies[indexPath.row]
        selectedSpecies.remove(species.id)
        
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .none
        }
    }
}
