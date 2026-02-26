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

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var selectedLocationNameLabel: UILabel!
    @IBOutlet weak var selectedLocationDetailLabel: UILabel!

    private var displayedPredictions: [FinalPredictionResult] = []
    private var yearlySeriesByBird: [String: [Int]] = [:]
    private var selectedPredictionIndex: Int = 0
    private let geocoder = CLGeocoder()
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
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            guard self.headerLocationRequestID == requestID else { return }
            guard let placemark = placemarks?.first else { return }

            let city = placemark.locality ?? placemark.subLocality
            let state = placemark.administrativeArea
            if let city, let state, !city.isEmpty, !state.isEmpty {
                self.selectedLocationDetailLabel.text = "\(city), \(state)"
            } else {
                self.selectedLocationDetailLabel.text = city ?? state ?? placemark.country
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
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let oldIndex = selectedPredictionIndex
        selectedPredictionIndex = indexPath.item
        if oldIndex != selectedPredictionIndex {
            collectionView.reloadItems(at: [IndexPath(item: oldIndex, section: 0), indexPath])
        } else {
            collectionView.reloadItems(at: [indexPath])
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
        let cardHeight: CGFloat

        if cardWidth > 450 {
            cardHeight = min(calculatedHeight, 180)
        } else {
            cardHeight = calculatedHeight
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
