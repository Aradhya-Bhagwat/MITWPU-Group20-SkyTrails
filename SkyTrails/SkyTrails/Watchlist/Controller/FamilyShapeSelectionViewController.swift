//
//  FamilyShapeSelectionViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 13/02/26.
//

import UIKit

protocol FamilyShapeSelectionDelegate: AnyObject {
    func didSelectFamiliesAndShapes(families: [String], shapes: [String])
}

class FamilyShapeSelectionViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    weak var delegate: FamilyShapeSelectionDelegate?
    var selectedFamilies: Set<String> = []
    var selectedShapes: Set<String> = []
    
    private var allFamilies: [String] = []
    private var allShapes: [String] = ["waterfowl", "raptor", "songbird", "shorebird", "seabird", "wading", "game"]
    private var filteredFamilies: [String] = []
    private var filteredShapes: [String] = []
    
    enum Section: Int, CaseIterable {
        case shapes
        case families
        
        var title: String {
            switch self {
            case .shapes: return "Shapes"
            case .families: return "Families"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Families & Shapes"
        
        // Add Done button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(didTapDone)
        )
        
        loadFamilies()
        setupTableView()
        searchBar.delegate = self
    }
    
    private func loadFamilies() {
        // Extract unique families from Bird database
        let manager = WatchlistManager.shared
        let allBirds = manager.fetchAllBirds()
        allFamilies = Array(Set(allBirds.compactMap { $0.family })).sorted()
        filteredFamilies = allFamilies
        filteredShapes = allShapes
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        // Use basic cell for simplicity
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    @objc private func didTapDone() {
        delegate?.didSelectFamiliesAndShapes(
            families: Array(selectedFamilies),
            shapes: Array(selectedShapes)
        )
        navigationController?.popViewController(animated: true)
    }
    
    private func filterContentForSearchText(_ searchText: String) {
        if searchText.isEmpty {
            filteredFamilies = allFamilies
            filteredShapes = allShapes
        } else {
            filteredFamilies = allFamilies.filter { $0.lowercased().contains(searchText.lowercased()) }
            filteredShapes = allShapes.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
        tableView.reloadData()
    }
}

extension FamilyShapeSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        if sectionType == .shapes && filteredShapes.isEmpty { return nil }
        if sectionType == .families && filteredFamilies.isEmpty { return nil }
        
        return sectionType.title
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .shapes: return filteredShapes.count
        case .families: return filteredFamilies.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return cell }
        
        let text: String
        let isSelected: Bool
        
        switch sectionType {
        case .shapes:
            text = filteredShapes[indexPath.row]
            isSelected = selectedShapes.contains(text)
        case .families:
            text = filteredFamilies[indexPath.row]
            isSelected = selectedFamilies.contains(text)
        }
        
        var content = cell.defaultContentConfiguration()
        content.text = text
        cell.contentConfiguration = content
        
        cell.accessoryType = isSelected ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        
        switch sectionType {
        case .shapes:
            let shape = filteredShapes[indexPath.row]
            if selectedShapes.contains(shape) {
                selectedShapes.remove(shape)
            } else {
                selectedShapes.insert(shape)
            }
        case .families:
            let family = filteredFamilies[indexPath.row]
            if selectedFamilies.contains(family) {
                selectedFamilies.remove(family)
            } else {
                selectedFamilies.insert(family)
            }
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}

extension FamilyShapeSelectionViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterContentForSearchText(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
