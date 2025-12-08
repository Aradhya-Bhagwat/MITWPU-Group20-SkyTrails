//
//  SpeciesSelectionViewController.swift
//  SkyTrails
//
//  Created by Gemini on 07/12/25.
//

import UIKit

class SpeciesSelectionViewController: UIViewController {

    // MARK: - Outlets
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
        // Fetch all birds via ViewModel (simulated search)
        // Use the injected VM or create a temporary one to ensure data is always available
        let vm = viewModel ?? WatchlistViewModel()
        
        let all = vm.watchlists.flatMap { $0.birds }
        // De-duplicate
        var unique = [UUID: Bird]()
        for b in all { unique[b.id] = b }
        self.allBirds = Array(unique.values).sorted { $0.name < $1.name }
        
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdSmartCell", for: indexPath) as? BirdSmartCell else {
            return UITableViewCell()
        }
        
        let bird = filteredBirds[indexPath.row]
        cell.shouldShowAvatars = false
        cell.configure(with: bird)
        
        // Custom overrides for Species Selection
        cell.dateLabel.isHidden = true
        
        let rarityString = bird.rarity.map { "\($0)" }.joined(separator: ", ").capitalized
        cell.locationLabel.text = rarityString.isEmpty ? "Unknown" : rarityString
        cell.locationLabel.textColor = .systemOrange
        
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
		
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
