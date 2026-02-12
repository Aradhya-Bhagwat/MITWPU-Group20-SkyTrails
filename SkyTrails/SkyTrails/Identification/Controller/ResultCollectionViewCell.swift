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

    @IBOutlet weak var cardContainerView: UIView!
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
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        cardContainerView.layer.cornerRadius = 12
        cardContainerView.layer.masksToBounds = true
        setupMenu()
        updateSelectionAppearance()
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        resultImageView.image = nil
        nameLabel.text = nil
        percentageLabel.text = nil
        isSelectedCell = false
        updateSelectionAppearance()
    }

    // MARK: - Configuration

    func configure(image: UIImage?, name: String, percentage: String) {
        resultImageView.image = image
        nameLabel.text = name
        percentageLabel.text = percentage + "%"
        nameLabel.textColor = .label
        percentageLabel.textColor = .secondaryLabel
        menuButton.tintColor = .secondaryLabel
    }
    
    func configureHistory(image: UIImage?, name: String, date: String) {
        resultImageView.image = image
        nameLabel.text = name
        percentageLabel.text = date
        nameLabel.textColor = .label
        percentageLabel.textColor = .secondaryLabel
        menuButton.tintColor = .secondaryLabel
    }

    // MARK: - Selection Appearance

    private func updateSelectionAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let unselectedColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        layer.cornerRadius = 12
        layer.masksToBounds = false
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true

        if isSelectedCell {
            if isDarkMode {
                contentView.layer.borderWidth = 0
                contentView.layer.borderColor = UIColor.clear.cgColor
                contentView.backgroundColor = .secondarySystemBackground
                cardContainerView.backgroundColor = .secondarySystemBackground
            } else {
                contentView.layer.borderWidth = 3
                contentView.layer.borderColor = UIColor.systemBlue.cgColor
                contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                cardContainerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            }
        } else {
            contentView.layer.borderWidth = isDarkMode ? 0 : 1
            contentView.layer.borderColor = isDarkMode ? UIColor.clear.cgColor : UIColor.systemGray4.cgColor
            contentView.backgroundColor = unselectedColor
            cardContainerView.backgroundColor = unselectedColor
        }

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
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSelectionAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        updateSelectionAppearance()
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
