//
//  SpeciesSelectionViewController.swift
//  SkyTrails
//
//  Created by Gemini on 07/12/25.
//

import UIKit

class SpeciesSelectionViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var visualEffectView: UIVisualEffectView!
    @IBOutlet weak var headerIconView: UIImageView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    var mode: WatchlistMode = .observed
    var viewModel: WatchlistViewModel?
    weak var coordinator: WatchlistCoordinator?
    
    private var allBirds: [Bird] = []
    private var filteredBirds: [Bird] = []
    private var selectedBirds: Set<UUID> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    private func setupUI() {
        title = "Select Species"
        
        // Header Logic
        if mode == .observed {
            visualEffectView.isHidden = false
            headerIconView.isHidden = false
            headerIconView.image = UIImage(systemName: "rectangle.stack.badge.plus")
            headerImageView.image = UIImage(named: "AsianFairyBluebird") // Ambient background
        } else {
            visualEffectView.isHidden = true
            headerIconView.isHidden = true
            headerImageView.image = UIImage(named: "HimalayanMonal") // Generic header or specific
        }
        
        // TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        
        // Search
        searchBar.delegate = self
        
        // Navigation Button
        updateNextButton()
    }
    
    private func loadData() {
        // Fetch all birds
        allBirds = viewModel?.searchBirds(query: "") ?? []
        filteredBirds = allBirds
        tableView.reloadData()
    }
    
    private func updateNextButton() {
        let iconName = selectedBirds.isEmpty ? "plus" : "checkmark"
        let item = UIBarButtonItem(image: UIImage(systemName: iconName), style: .plain, target: self, action: #selector(didTapNext))
        navigationItem.rightBarButtonItem = item
    }
    
    @objc private func didTapNext() {
        guard !selectedBirds.isEmpty else { return }
        
        // Collect selected bird objects
        let birds = allBirds.filter { selectedBirds.contains($0.id) }
        
        // Start Loop
        coordinator?.startDetailLoop(birds: birds, mode: mode)
    }
}

extension SpeciesSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredBirds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpeciesCell", for: indexPath)
        let bird = filteredBirds[indexPath.row]
        
        var config = cell.defaultContentConfiguration()
        config.text = bird.name
        config.secondaryText = bird.scientificName
        // Minimal image logic for prototype
        if let imageName = bird.images.first {
            config.image = UIImage(named: imageName)
            config.imageProperties.cornerRadius = 8
            config.imageProperties.maximumSize = CGSize(width: 40, height: 40)
        }
        cell.contentConfiguration = config
        
        cell.accessoryType = selectedBirds.contains(bird.id) ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let bird = filteredBirds[indexPath.row]
        if selectedBirds.contains(bird.id) {
            selectedBirds.remove(bird.id)
        } else {
            selectedBirds.insert(bird.id)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateNextButton()
    }
}

extension SpeciesSelectionViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredBirds = allBirds
        } else {
            filteredBirds = allBirds.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        tableView.reloadData()
    }
}
