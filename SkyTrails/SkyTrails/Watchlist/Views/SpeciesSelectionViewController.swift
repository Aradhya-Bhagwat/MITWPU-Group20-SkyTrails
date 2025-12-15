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
    // var viewModel: WatchlistViewModel? // Removed
    var targetWatchlistId: UUID?
    
    private var allBirds: [Bird] = []
    private var filteredBirds: [Bird] = []
    private var selectedBirds: Set<UUID> = []
    
    // Local Loop State
    private var birdQueue: [Bird] = []
    private var processedBirds: [Bird] = []
    
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
        // Fetch all birds via Manager (simulated search)
        let manager = WatchlistManager.shared
        
        let all = manager.watchlists.flatMap { $0.birds }
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
        startDetailLoop(birds: birds)
    }
    
    // MARK: - Detail Loop Logic
    private func startDetailLoop(birds: [Bird]) {
        self.birdQueue = birds
        self.processedBirds = []
        showNextInLoop()
    }
    
    private func showNextInLoop() {
        // If queue is empty, we are done
        if birdQueue.isEmpty {
            if !processedBirds.isEmpty {
                print("Loop finished. Updating data with \(processedBirds.count) birds.")
                if let watchlistId = targetWatchlistId {
                    let isObserved = (mode == .observed)
                    WatchlistManager.shared.addBirds(processedBirds, to: watchlistId, asObserved: isObserved)
                }
            }
            
            // Navigate Back
            navigationController?.popViewController(animated: true)
            return
        }
        
        let bird = birdQueue.removeFirst()
        showBirdDetail(bird: bird)
    }
    
    private func showBirdDetail(bird: Bird) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        var nextVC: UIViewController?

        if mode == .unobserved {
            let vc = storyboard.instantiateViewController(withIdentifier: "UnobservedDetailViewController") as! UnobservedDetailViewController
            vc.bird = bird
            // We do NOT pass watchlistId because we want to intercept save
            vc.onSave = { [weak self] savedBird in
                self?.processedBirds.append(savedBird)
                self?.showNextInLoop()
            }
            nextVC = vc
        } else if mode == .observed {
            let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as! ObservedDetailViewController
            vc.bird = bird
            // No watchlistId passed, so it triggers onSave
            vc.onSave = { [weak self] savedBird in
                self?.processedBirds.append(savedBird)
                self?.showNextInLoop()
            }
            nextVC = vc
        }

        guard let vc = nextVC else { return }

        // MARK: - Memory Fix
        // Instead of pushing endlessly, we replace the current detail view if one exists.
        var vcs = navigationController?.viewControllers ?? []
        if let last = vcs.last, (last is ObservedDetailViewController || last is UnobservedDetailViewController) {
            vcs.removeLast()
        }
        vcs.append(vc)
        navigationController?.setViewControllers(vcs, animated: true)
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
