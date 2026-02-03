//
//  SummaryCardCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class SummaryCardCollectionViewCell: UICollectionViewCell {

    static let identifier = "SummaryCardCollectionViewCell"
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCardStyle()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
    }
    
    private func setupCardStyle() {
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.masksToBounds = false
    }
    
    func configure(number: String, title: String, color: UIColor) {
        numberLabel.text = number
        numberLabel.textColor = color
        titleLabel.text = title
        subtitleLabel.text = "Species"
    }
}
