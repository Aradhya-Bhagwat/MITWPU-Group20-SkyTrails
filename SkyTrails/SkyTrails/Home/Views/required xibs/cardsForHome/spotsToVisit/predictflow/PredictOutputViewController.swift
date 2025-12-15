//
//  PredictOutputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit
import CoreLocation

class PredictOutputViewController: UIViewController {
    
    // Data passed from PredictMapViewController
    var predictions: [FinalPredictionResult] = []
    var inputData: [PredictionInputData] = []
    
    // Data organized by input index to match cards
    private var organizedPredictions: [[FinalPredictionResult]] = []
    
    // UI Elements
    private var collectionView: UICollectionView!
    private let pageControl = UIPageControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupNavigation()
        organizeData()
        setupCollectionView()
        setupPageControl()
    }
    
    private func organizeData() {
        // Initialize array with empty lists for each input card
        organizedPredictions = Array(repeating: [], count: inputData.count)
        
        for prediction in predictions {
            let index = prediction.matchedInputIndex
            // Ensure the index is valid
            if index >= 0 && index < organizedPredictions.count {
                organizedPredictions[index].append(prediction)
            }
        }
    }
    
    private func setupNavigation() {
        // Title
        navigationItem.title = "Prediction Results"
        
        // Redo Button (Top Right)
        let redoButton = UIBarButtonItem(title: "Redo", style: .plain, target: self, action: #selector(didTapRedo))
        navigationItem.rightBarButtonItem = redoButton
        
        // Clear left bar button item
        navigationItem.leftBarButtonItem = nil
    }
    
    private func setupCollectionView() {
        // Custom Layout
        let layout = CardSnappingLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        
        let screenWidth = UIScreen.main.bounds.width
        // Card size: width = screen - 48 (margins), height = 320 (similar to input)
        layout.itemSize = CGSize(width: screenWidth - 48, height: 400) // Increased height for output list
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.decelerationRate = .fast
        collectionView.showsHorizontalScrollIndicator = false
        
        // Register Cell
        collectionView.register(PredictionOutputCardCell.self, forCellWithReuseIdentifier: "PredictionOutputCardCell")
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 420) // Constraint for the collection view height
        ])
    }
    
    private func setupPageControl() {
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = inputData.count
        pageControl.currentPage = 0
        pageControl.hidesForSinglePage = true
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.currentPageIndicatorTintColor = .label
        pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        
        view.addSubview(pageControl)
        
        NSLayoutConstraint.activate([
            pageControl.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 8),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
    
    @objc func pageControlChanged(_ sender: UIPageControl) {
        let indexPath = IndexPath(item: sender.currentPage, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
    // MARK: - Navigation Actions
    
    @objc private func didTapRedo() {
        if let mapVC = self.navigationController?.parent as? PredictMapViewController {
            mapVC.revertToInputScreen(with: inputData)
        } else {
            print("❌ Redo failed: Could not find PredictMapViewController grandparent.")
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func updatePageControl() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        
        let itemWidth = layout.itemSize.width
        let spacing = layout.minimumLineSpacing
        let stride = itemWidth + spacing
        let offset = collectionView.contentOffset.x
        
        let index = Int(round(offset / stride))
        let safeIndex = max(0, min(index, inputData.count - 1))
        
        if pageControl.currentPage != safeIndex {
            pageControl.currentPage = safeIndex
        }
    }
}

// MARK: - Collection View DataSource & Delegate
extension PredictOutputViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return inputData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PredictionOutputCardCell", for: indexPath) as? PredictionOutputCardCell else {
            return UICollectionViewCell()
        }
        
        let locationName = inputData[indexPath.row].locationName ?? "Location \(indexPath.row + 1)"
        let cardPredictions = organizedPredictions[indexPath.row]
        
        cell.configure(location: locationName, data: cardPredictions)
        
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updatePageControl()
    }
}

// MARK: - Custom Card Cell with TableView
class PredictionOutputCardCell: UICollectionViewCell, UITableViewDataSource, UITableViewDelegate {
    
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private var predictions: [FinalPredictionResult] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Card Styling
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        
        // Title Label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        
        // TableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(BirdResultCell.self, forCellReuseIdentifier: "BirdResultCell")
        tableView.dataSource = self
        tableView.delegate = self
        contentView.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            // Title Constraints
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // TableView Constraints
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(location: String, data: [FinalPredictionResult]) {
        titleLabel.text = location
        self.predictions = data
        tableView.reloadData()
    }
    
    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdResultCell", for: indexPath) as? BirdResultCell else {
            return UITableViewCell()
        }
        
        let prediction = predictions[indexPath.row]
        cell.configure(with: prediction.birdName, imageName: prediction.imageName)
        // Adjust cell background for card context
        cell.backgroundColor = .clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - Bird Result Cell (Reused)
class BirdResultCell: UITableViewCell {
    
    private let birdImageView = UIImageView()
    private let birdNameLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        birdImageView.translatesAutoresizingMaskIntoConstraints = false
        birdImageView.contentMode = .scaleAspectFit
        birdImageView.clipsToBounds = true
        birdImageView.layer.cornerRadius = 8 // Slight roundness
        
        birdNameLabel.translatesAutoresizingMaskIntoConstraints = false
        birdNameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        
        contentView.addSubview(birdImageView)
        contentView.addSubview(birdNameLabel)
        
        NSLayoutConstraint.activate([
            birdImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            birdImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 60),
            birdImageView.heightAnchor.constraint(equalToConstant: 60),
            
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
        birdImageView.image = UIImage(named: imageName) ?? UIImage(systemName: "photo")
    }
}