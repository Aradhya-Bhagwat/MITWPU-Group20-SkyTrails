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
    
    private var currentStartDate: Date = Date()
    private var currentEndDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    
    private let imageView = UIImageView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        

        if !collectedData.isEmpty {

        }
        
        setupNavigationBar()
        setupUI()
        loadCurrentBird()
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {

        let nextTitle = (currentIndex == speciesList.count - 1) ? "Done" : "Next"
        let nextButton = UIBarButtonItem(title: nextTitle, style: .plain  , target: self, action: #selector(didTapNext))
        
        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didTapDelete))
        
        navigationItem.rightBarButtonItems = [nextButton, deleteButton]
    }
    
    private func setupUI() {

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .systemGray6
        
        view.addSubview(imageView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DateCell")
        tableView.isScrollEnabled = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([

            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 240),
            imageView.heightAnchor.constraint(equalToConstant: 160),
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
        var newCollection = collectedData
        newCollection.append(input)
        
        if currentIndex < speciesList.count - 1 {

            let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
            guard let nextVC = storyboard.instantiateViewController(withIdentifier: "BirdDateInputViewController") as? BirdDateInputViewController else { return }
            
            nextVC.speciesList = self.speciesList
            nextVC.currentIndex = self.currentIndex + 1
            nextVC.collectedData = newCollection
            
            navigationController?.pushViewController(nextVC, animated: true)
            
        } else {
            
            let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
            guard let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController else { return }
            
            mapVC.predictionInputs = newCollection
            
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    @objc private func didTapDelete() {

        var newSpeciesList = speciesList
        newSpeciesList.remove(at: currentIndex)
        
        if newSpeciesList.isEmpty {

            navigationController?.popToRootViewController(animated: true)
            return
        }
        
        if currentIndex < newSpeciesList.count {
            


            
            let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
            guard let nextVC = storyboard.instantiateViewController(withIdentifier: "BirdDateInputViewController") as? BirdDateInputViewController else { return }
            
            nextVC.speciesList = newSpeciesList
            nextVC.currentIndex = currentIndex
            nextVC.collectedData = collectedData
            
            navigationController?.pushViewController(nextVC, animated: true)
            
        } else {
            
            if !collectedData.isEmpty {

                let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
                guard let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController else { return }
                mapVC.predictionInputs = collectedData
                navigationController?.pushViewController(mapVC, animated: true)
            } else {

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
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "DateCell")
        cell.selectionStyle = .none
        
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        
        if indexPath.row == 0 {
            cell.textLabel?.text = "Start Date"
            datePicker.date = currentStartDate
            datePicker.addTarget(self, action: #selector(startDateChanged(_:)), for: .valueChanged)
        } else {
            cell.textLabel?.text = "End Date"
            datePicker.date = currentEndDate
            datePicker.addTarget(self, action: #selector(endDateChanged(_:)), for: .valueChanged)
        }

        cell.accessoryView = datePicker
        
        return cell
    }
}
