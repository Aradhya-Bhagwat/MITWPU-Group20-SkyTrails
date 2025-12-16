//
//  SectionHeaderCollectionReusableView.swift
//  SkyTrails
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class SectionHeaderCollectionReusableView: UICollectionReusableView {
	static var identifier: String = "SectionHeaderCollectionReusableView"
    
    @IBOutlet weak var chevronButton: UIButton!
	@IBOutlet weak var sectionTitle: UILabel!
    
    var onChevronTap: (() -> Void)?
    
	override func awakeFromNib() {
		super.awakeFromNib()
		setupStyle()
    
        
	}
	
    private func setupStyle() {
            sectionTitle.font = UIFont.preferredFont(forTextStyle: .headline)
            sectionTitle.textColor = .label
            sectionTitle.font = UIFont.systemFont(ofSize: 20, weight: .bold)
            

            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            let image = UIImage(systemName: "chevron.right", withConfiguration: config)
            chevronButton.setImage(image, for: .normal)
            chevronButton.tintColor = .label
        }
	
    func configure(title: String, tapAction: (() -> Void)? = nil) {
            sectionTitle.text = title
            onChevronTap = tapAction
            

            chevronButton.isHidden = (tapAction == nil)
        }
        

        @IBAction func didTapChevron(_ sender: Any) {

            onChevronTap?()
        }
}
