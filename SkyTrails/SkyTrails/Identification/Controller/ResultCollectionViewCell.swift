//
//  ResultCollectionViewCell.swift
//  SkyTrails
//
//  Created by Disha Jain on 19/01/26.
//

import UIKit

protocol ResultCellDelegate: AnyObject {
    func didTapPredict(for cell: ResultCollectionViewCell)
    func didTapAddToWatchlist(for cell: ResultCollectionViewCell)
}

class ResultCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var resultImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var percentageLabel: UILabel!
    @IBOutlet weak var menuButton: UIButton!
    
    weak var delegate: ResultCellDelegate?
    var indexPath: IndexPath?
    var isSelectedCell: Bool = false {
            didSet {
                updateSelectionAppearance()
            }
        }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupMenu()
    }
  
    func configure(image: UIImage?, name: String, percentage: String) {
        resultImageView.image = image
        nameLabel.text = name
        percentageLabel.text = percentage + "%"
    }
    
    func configureHistory(image: UIImage?, name: String, date: String) {
        resultImageView.image = image
        nameLabel.text = name
        percentageLabel.text = date
    }
    private func updateSelectionAppearance() {
            if isSelectedCell {
                self.layer.borderWidth = 3.0
                self.layer.borderColor = UIColor.systemBlue.cgColor
            } 
        }
    
    
    func setupMenu() {
        let predictAction = UIAction(title: "Predict Species",
                                     image: UIImage(systemName: "map")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didTapPredict(for: self)
        }

        let watchlistAction = UIAction(title: "Add to Watchlist",
                                       image: UIImage(systemName: "text.badge.plus")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didTapAddToWatchlist(for: self)
        }

        let menu = UIMenu(title: "", children: [predictAction, watchlistAction])
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = menu
    }
   
}

