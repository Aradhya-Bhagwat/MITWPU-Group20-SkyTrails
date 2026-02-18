//
//  WatchlitEmptyCollectionViewCell.swift
//  SkyTrails
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit

final class WatchlitEmptyCollectionViewCell: UICollectionViewCell {

	static let identifier = "WatchlitEmptyCollectionViewCell"

	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var emptyImageView: UIImageView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var subtitleLabel: UILabel!

	override func awakeFromNib() {
		super.awakeFromNib()
		setupUI()
	}

	private func setupUI() {
		containerView.layer.cornerRadius = 20
		containerView.layer.borderWidth = 1
		containerView.layer.borderColor = UIColor.systemGray5.cgColor
		containerView.backgroundColor = .secondarySystemGroupedBackground
		containerView.layer.masksToBounds = true

		emptyImageView.contentMode = .scaleAspectFill
		emptyImageView.clipsToBounds = true

		titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
		titleLabel.textColor = .label
		titleLabel.numberOfLines = 2

		subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.numberOfLines = 2
	}

	func configure(imageName: String, title: String, subtitle: String) {
		titleLabel.text = title
		subtitleLabel.text = subtitle
		emptyImageView.image = UIImage(named: imageName) ?? UIImage(named: imageName + " ")
	}
}
