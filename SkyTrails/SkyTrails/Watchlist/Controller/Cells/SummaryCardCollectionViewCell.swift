//
//  SummaryCardCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class SummaryCardCollectionViewCell: UICollectionViewCell {

    static let identifier = "SummaryCardCollectionViewCell"
    private var defaultContainerBackgroundColor: UIColor = .white
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        defaultContainerBackgroundColor = containerView.backgroundColor ?? .white
        setupCardStyle()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
    }
    
    private func setupCardStyle() {
        updateCardAppearance()
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = false
    }

    private func updateCardAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        containerView.backgroundColor = isDarkMode ? .secondarySystemBackground : defaultContainerBackgroundColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = isDarkMode ? 0 : 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
    }
    
    func configure(number: String, title: String, color: UIColor) {
        updateCardAppearance()
        numberLabel.text = number
        numberLabel.textColor = color
        titleLabel.text = title
        subtitleLabel.text = "Species"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardAppearance()
    }
}
