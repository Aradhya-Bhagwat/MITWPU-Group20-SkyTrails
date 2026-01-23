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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let topPadding = view.safeAreaInsets.top - 40
        collectionView.frame = CGRect(x: 0, y: topPadding, width: view.bounds.width, height: 420)
        
        let pcTop = collectionView.frame.maxY + 8
        pageControl.frame = CGRect(x: 0, y: pcTop, width: view.bounds.width, height: 26)
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
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        
        let screenWidth = view.bounds.width
       
        layout.itemSize = CGSize(width: screenWidth - 48, height: 320)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.decelerationRate = .fast
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(UINib(nibName: PredictionOutputCardCell.identifier, bundle: nil), forCellWithReuseIdentifier: PredictionOutputCardCell.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        
        view.addSubview(collectionView)
    }
    
    private func setupPageControl() {
        pageControl.numberOfPages = inputData.count
        pageControl.currentPage = 0
        pageControl.hidesForSinglePage = true
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.currentPageIndicatorTintColor = .label
        pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        
        view.addSubview(pageControl)
    }
    
    @objc func pageControlChanged(_ sender: UIPageControl) {
        let indexPath = IndexPath(item: sender.currentPage, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
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
        cell.onSelectPrediction = { [weak self] selectedPrediction in
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

class BirdResultCell: UITableViewCell {
    
    private let birdImageView = UIImageView()
    private let birdNameLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        birdImageView.contentMode = .scaleAspectFill
        birdImageView.clipsToBounds = true
        birdImageView.layer.cornerRadius = 8
        
        birdNameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        
        contentView.addSubview(birdImageView)
        contentView.addSubview(birdNameLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let height = contentView.bounds.height
        let width = contentView.bounds.width
        let imageSize: CGFloat = 60
        birdImageView.frame = CGRect(x: 16, y: (height - imageSize) / 2, width: imageSize, height: imageSize)
        let labelX = birdImageView.frame.maxX + 16
        let labelWidth = width - labelX - 16
        birdNameLabel.frame = CGRect(x: labelX, y: 0, width: labelWidth, height: height)
    }
    
    func configure(with name: String, imageName: String) {
        birdNameLabel.text = name
        birdImageView.image = UIImage(named: imageName) ?? UIImage(systemName: "photo")
    }
}
