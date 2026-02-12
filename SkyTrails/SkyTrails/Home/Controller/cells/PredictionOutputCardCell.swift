//
//  PredictionOutputCardCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class PredictionOutputCardCell: UICollectionViewCell, UITableViewDataSource, UITableViewDelegate {
    
    static let identifier = "PredictionOutputCardCell"
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    private var predictions: [FinalPredictionResult] = []
    
    var onSelectPrediction: ((FinalPredictionResult) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        applySemanticAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if traitCollection.userInterfaceStyle != .dark {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        applySemanticAppearance()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        layer.cornerRadius = 16
        layer.masksToBounds = false
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        titleLabel.textColor = .label
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(BirdResultCell.self, forCellReuseIdentifier: "BirdResultCell")
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        containerView.backgroundColor = cardColor
        titleLabel.textColor = .label

        if isDarkMode {
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
            layer.shadowPath = nil
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.08
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 6
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        }
    }
    
    func configure(location: String, data: [FinalPredictionResult]) {
        titleLabel.text = location
        self.predictions = data
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdResultCell", for: indexPath) as? BirdResultCell else {
            return UITableViewCell()
        }
        
        let prediction = predictions[indexPath.row]
        cell.configure(with: prediction.birdName, imageName: prediction.imageName)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .default
        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.systemBlue.withAlphaComponent(
            traitCollection.userInterfaceStyle == .dark ? 0.24 : 0.10
        )
        cell.selectedBackgroundView = selectedView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedPrediction = predictions[indexPath.row]
        onSelectPrediction?(selectedPrediction)
    }
}
