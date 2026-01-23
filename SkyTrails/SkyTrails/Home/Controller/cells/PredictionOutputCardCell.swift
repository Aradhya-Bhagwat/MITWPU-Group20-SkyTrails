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
    }
    
    private func setupUI() {

        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(BirdResultCell.self, forCellReuseIdentifier: "BirdResultCell")
        tableView.dataSource = self
        tableView.delegate = self
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
        cell.selectionStyle = .none
        cell.selectionStyle = .default
        
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
