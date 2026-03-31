//
//  PredictionButtonCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/03/26.
//

import UIKit

class PredictionButtonCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "PredictionButtonCollectionViewCell"
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    
    private let symbolImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = .systemTeal
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemTeal
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
        setupAppearance()
        applySemanticAppearance()
    }
    
    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }
    
    private func setupAppearance() {
        self.backgroundColor = .clear
        self.clipsToBounds = false
        
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        
        imageView.contentMode = .center
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.1)
        imageView.tintColor = .systemTeal
        imageView.image = nil // Background only
        
        containerView.addSubview(symbolImageView)
        containerView.addSubview(titleLabel)
        containerView.bringSubviewToFront(titleLabel)
        containerView.bringSubviewToFront(symbolImageView)
        
        NSLayoutConstraint.activate([
            symbolImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            symbolImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
        ])
    }
    
    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = cardColor

        if isDarkMode {
            contentView.layer.shadowOpacity = 0
            contentView.layer.shadowRadius = 0
            contentView.layer.shadowOffset = .zero
            contentView.layer.shadowPath = nil
        } else {
            contentView.layer.shadowColor = UIColor.black.cgColor
            contentView.layer.shadowOpacity = 0.08
            contentView.layer.shadowOffset = CGSize(width: 0, height: 3)
            contentView.layer.shadowRadius = 6
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard containerView != nil, imageView != nil else { return }
        
        if traitCollection.userInterfaceStyle != .dark {
            contentView.layer.shadowPath = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 16).cgPath
        }
    }
    
    func configure(with image: UIImage?, title: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .bold)
        symbolImageView.image = image?.withConfiguration(config).withRenderingMode(.alwaysTemplate)
        titleLabel.text = title
    }
}
