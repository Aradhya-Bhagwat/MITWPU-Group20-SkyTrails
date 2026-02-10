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

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset selection state so recycled cells don't carry stale borders
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.backgroundColor = .white
        resultImageView.image = nil
        nameLabel.text = nil
        percentageLabel.text = nil
    }

    // MARK: - Configuration

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

    // MARK: - Selection Appearance

    private func updateSelectionAppearance() {
        if isSelectedCell {
            contentView.layer.borderWidth = 3.0
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
            contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } else {
            // ← was missing: reset back to unselected state
            contentView.layer.borderWidth = 1.0
            contentView.layer.borderColor = UIColor.systemGray4.cgColor
            contentView.backgroundColor = .white
        }
    }

    // MARK: - Context Menu

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
