//
//  PredictOutputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit
import CoreLocation

class PredictOutputViewController: UIViewController {
    
    var predictions: [FinalPredictionResult] = []
    var inputData: [PredictionInputData] = []
    
    private var organizedPredictions: [[FinalPredictionResult]] = []
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

        organizedPredictions = Array(repeating: [], count: inputData.count)
        
        for prediction in predictions {
            let index = prediction.matchedInputIndex

            if index >= 0 && index < organizedPredictions.count {
                organizedPredictions[index].append(prediction)
            }
        }
    }
    
    private func setupNavigation() {
        navigationItem.title = "Prediction Results"
        let redoButton = UIBarButtonItem(title: "Redo", style: .plain, target: self, action: #selector(didTapRedo))
        navigationItem.rightBarButtonItem = redoButton
        
        navigationItem.leftBarButtonItem = nil
    }
    
    private func setupCollectionView() {
        // Standard Flow Layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        
        let screenWidth = UIScreen.main.bounds.width
       
        layout.itemSize = CGSize(width: screenWidth - 48, height: 320)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.decelerationRate = .fast
        collectionView.showsHorizontalScrollIndicator = false
        
        // Register Cell from XIB
        collectionView.register(UINib(nibName: PredictionOutputCardCell.identifier, bundle: nil), forCellWithReuseIdentifier: PredictionOutputCardCell.identifier)
        
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
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PredictionOutputCardCell.identifier, for: indexPath) as? PredictionOutputCardCell else {
            return UICollectionViewCell()
        }
        
        let locationName = inputData[indexPath.row].locationName ?? "Location \(indexPath.row + 1)"
        let cardPredictions = organizedPredictions[indexPath.row]
        
        cell.configure(location: locationName, data: cardPredictions)
        
        // Handle Bird Selection
        cell.onSelectPrediction = { [weak self] selectedPrediction in
            // Bubble up to Parent Map VC
            if let mapVC = self?.navigationController?.parent as? PredictMapViewController {
                mapVC.filterMapForBird(selectedPrediction)
            }
        }
        
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updatePageControl()
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
