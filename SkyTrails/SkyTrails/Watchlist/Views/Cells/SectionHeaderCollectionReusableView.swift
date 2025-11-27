//
//  SectionHeaderCollectionReusableView.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class SectionHeaderCollectionReusableView: UICollectionReusableView {
	static var identifier: String = "SectionHeaderCollectionReusableView"
	@IBOutlet weak var sectionTitle: UILabel!
	override func awakeFromNib() {
		super.awakeFromNib()
		setupStyle()
	}
	
	private func setupStyle() {
		sectionTitle.font = UIFont.preferredFont(forTextStyle: .headline)
	
		sectionTitle.textColor = .label
	}
	
	func configure(title: String) {
		sectionTitle.text = title
	}
    
}
