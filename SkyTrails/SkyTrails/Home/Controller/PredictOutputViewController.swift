//
//  PredictOutputViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit
import CoreLocation
import MapKit

class PredictOutputViewController: UIViewController {
    var predictions: [FinalPredictionResult] = []
    var inputData: [PredictionInputData] = []

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var selectedLocationNameLabel: UILabel!
    @IBOutlet weak var selectedLocationDetailLabel: UILabel!

    private var displayedPredictions: [FinalPredictionResult] = []
    private var yearlySeriesByBird: [String: [Int]] = [:]
    private var selectedPredictionIndex: Int = 0
    private var headerLocationRequestID: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        applySemanticAppearance()

        setupNavigation()
        prepareData()
        setupCollectionView()
        updateLocationHeader(forDisplayedPredictionAt: selectedPredictionIndex)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLabelTypography()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
        updateHeaderLabelTypography()
        collectionView?.reloadData()
    }

    private func prepareData() {
        displayedPredictions = predictions.sorted { lhs, rhs in
            if lhs.spottingProbability == rhs.spottingProbability {
                return lhs.birdName < rhs.birdName
            }
            return lhs.spottingProbability > rhs.spottingProbability
        }

        for prediction in displayedPredictions {
            guard yearlySeriesByBird[prediction.birdName] == nil else { continue }
            yearlySeriesByBird[prediction.birdName] = yearlySeries(for: prediction)
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
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColor = .clear
        collectionView.decelerationRate = .normal
        collectionView.showsVerticalScrollIndicator = true
        collectionView.register(
            UINib(
                nibName: spotsToVisitOutputCollectionViewCell.identifier,
                bundle: Bundle(for: spotsToVisitOutputCollectionViewCell.self)
            ),
            forCellWithReuseIdentifier: spotsToVisitOutputCollectionViewCell.identifier
        )
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    private func applySemanticAppearance() {
        view.backgroundColor = .systemBackground
        collectionView?.backgroundColor = .clear
        navigationItem.rightBarButtonItem?.tintColor = .systemBlue
    }

    @objc private func didTapRedo() {
        if let mapVC = self.navigationController?.parent as? PredictMapViewController {
            mapVC.revertToInputScreen(with: inputData)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    private func yearlySeries(for prediction: FinalPredictionResult) -> [Int] {
        let location = CLLocationCoordinate2D(
            latitude: prediction.matchedLocation.lat,
            longitude: prediction.matchedLocation.lon
        )
        return HomeManager.shared.yearlySightabilitySeries(
            forBirdNamed: prediction.birdName,
            near: location
        )
    }

    private func updateLocationHeader(forDisplayedPredictionAt index: Int) {
        guard displayedPredictions.indices.contains(index) else {
            selectedLocationNameLabel.text = "Search Location"
            selectedLocationDetailLabel.text = nil
            return
        }

        let prediction = displayedPredictions[index]
        let inputIndex = prediction.matchedInputIndex
        let input = inputData.indices.contains(inputIndex) ? inputData[inputIndex] : nil
        selectedLocationNameLabel.text = input?.locationName ?? "Search Location"
        if let detail = input?.locationDetail, !detail.isEmpty {
            selectedLocationDetailLabel.text = detail
            return
        }

        guard let lat = input?.latitude, let lon = input?.longitude else {
            selectedLocationDetailLabel.text = nil
            return
        }

        selectedLocationDetailLabel.text = nil
        let requestID = UUID()
        headerLocationRequestID = requestID
        let location = CLLocation(latitude: lat, longitude: lon)
        Task {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                let mapItems = try await request.mapItems
                
                await MainActor.run {
                    guard self.headerLocationRequestID == requestID else { return }
                    guard let mapItem = mapItems.first else { return }
                    
                    if #available(iOS 26.0, *) {
                        if let cityState = mapItem.addressRepresentations?.cityWithContext(MKAddressRepresentations.ContextStyle.full) {
                            self.selectedLocationDetailLabel.text = cityState
                        } else {
                            self.selectedLocationDetailLabel.text = mapItem.addressRepresentations?.cityName ?? mapItem.name
                        }
                    } else {
                        let placemark = mapItem.placemark
                        let city = placemark.locality ?? placemark.subLocality
                        let state = placemark.administrativeArea
                        if let city, let state, !city.isEmpty, !state.isEmpty {
                            self.selectedLocationDetailLabel.text = "\(city), \(state)"
                        } else {
                            self.selectedLocationDetailLabel.text = city ?? state ?? placemark.country
                        }
                    }
                }
            } catch {
                print("Reverse geocoding failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateHeaderLabelTypography() {
        let containerHeight = max(1, view.bounds.height)
        let heightRatio = containerHeight / 874.0

        let titleSize = max(17, 17 * heightRatio)
        let subtitleSize = max(12, 12 * heightRatio)

        selectedLocationNameLabel.font = .systemFont(ofSize: titleSize, weight: .bold)
        selectedLocationDetailLabel.font = .systemFont(ofSize: subtitleSize, weight: .regular)
    }

    private func navigateToBirdPrediction(_ prediction: FinalPredictionResult) {
        // Find input dates if available
        let inputIndex = prediction.matchedInputIndex
        let input = inputData.indices.contains(inputIndex) ? inputData[inputIndex] : nil
        
        let startDate = input?.startDate ?? Date()
        let endDate = input?.endDate ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate) ?? startDate
        
        // Find actual bird ID from database to ensure path data can be found
        let birdID = WatchlistManager.shared.findBird(byName: prediction.birdName)?.id.uuidString ?? UUID().uuidString
        
        let birdInput = BirdDateInput(
            species: SpeciesData(id: birdID, name: prediction.birdName, imageName: prediction.imageName),
            startDate: startDate,
            endDate: endDate
        )

        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
            mapVC.predictionInputs = [birdInput]
            
            // Push onto the main navigation controller (replacing the PredictMapViewController)
            // self -> UINavigationController (child) -> PredictMapViewController (parent) -> UINavigationController (main)
            if let mainNav = self.navigationController?.parent?.navigationController {
                mainNav.pushViewController(mapVC, animated: true)
            } else {
                self.navigationController?.pushViewController(mapVC, animated: true)
            }
        }
    }

    private func addToWatchlist(_ prediction: FinalPredictionResult) {
        guard let bird = WatchlistManager.shared.findBird(byName: prediction.birdName) else {
            let alert = UIAlertController(title: "Error", message: "Could not find bird in database.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        do {
            try WatchlistManager.shared.addBirds([bird], to: WatchlistConstants.myWatchlistID, asObserved: false)
            let alert = UIAlertController(title: "Success", message: "\(prediction.birdName) added to your watchlist.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(title: "Error", message: "Failed to add bird to watchlist: \(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

extension PredictOutputViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedPredictions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: spotsToVisitOutputCollectionViewCell.identifier,
            for: indexPath
        ) as? spotsToVisitOutputCollectionViewCell else {
            return UICollectionViewCell()
        }

        let prediction = displayedPredictions[indexPath.item]
        let yearly = yearlySeriesByBird[prediction.birdName] ?? []
        cell.configure(prediction: prediction, yearlyProbabilities: yearly)
        cell.setCardSelected(indexPath.item == selectedPredictionIndex)
        
        cell.onTapBirdPath = { [weak self] selectedPrediction in
            self?.navigateToBirdPrediction(selectedPrediction)
        }
        
        cell.onTapWatchlist = { [weak self] selectedPrediction in
            self?.addToWatchlist(selectedPrediction)
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let oldIndex = selectedPredictionIndex
        selectedPredictionIndex = indexPath.item
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            collectionView.performBatchUpdates(nil)
            
            if let oldCell = collectionView.cellForItem(at: IndexPath(item: oldIndex, section: 0)) as? spotsToVisitOutputCollectionViewCell {
                oldCell.setCardSelected(false)
            }
            if let newCell = collectionView.cellForItem(at: indexPath) as? spotsToVisitOutputCollectionViewCell {
                newCell.setCardSelected(true)
            }
        }

        let prediction = displayedPredictions[indexPath.item]
        if let mapVC = navigationController?.parent as? PredictMapViewController {
            mapVC.filterMapForBird(prediction)
        }
        updateLocationHeader(forDisplayedPredictionAt: selectedPredictionIndex)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let cardWidth = collectionView.bounds.width - 32
        let compactAspectRatio: CGFloat = 6.0 / 17.0
        let calculatedHeight = cardWidth * compactAspectRatio
        var cardHeight: CGFloat

        if cardWidth > 450 {
            cardHeight = min(calculatedHeight, 180)
        } else {
            cardHeight = calculatedHeight
        }

        if indexPath.item == selectedPredictionIndex {
            cardHeight += 60
        }

        return CGSize(width: cardWidth, height: ceil(cardHeight))
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
        birdNameLabel.textColor = .label

        contentView.addSubview(birdImageView)
        contentView.addSubview(birdNameLabel)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
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
