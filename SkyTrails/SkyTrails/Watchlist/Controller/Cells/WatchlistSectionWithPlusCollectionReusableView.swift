//
//  WatchlistSectionWithPlusCollectionReusableView.swift
//  SkyTrails
//
//  Created by SDC-USER on 21/01/26.
//

import UIKit

class WatchlistSectionWithPlusCollectionReusableView: UICollectionReusableView {
    
    static var identifier: String = "WatchlistSectionWithPlusCollectionReusableView"
    
    @IBOutlet weak var sectionTitleLabel: UILabel!
    @IBOutlet weak var chevronButton: UIButton!
    @IBOutlet weak var plusButton: UIButton!
    
    weak var delegate: SectionHeaderDelegate?
    var sectionIndex: Int = 0
    var onPlusButtonTap: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupStyle()
    }
    
    private func setupStyle() {
        sectionTitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        sectionTitleLabel.textColor = .label
        
        // Make sure buttons have proper tint color
        chevronButton.tintColor = .label
        plusButton.tintColor = .label
    }
    
    func configure(
        title: String,
        sectionIndex: Int,
        showChevron: Bool = true,
        showPlus: Bool = true,
        delegate: SectionHeaderDelegate?,
        onPlusButtonTap: (() -> Void)? = nil
    ) {
        sectionTitleLabel.text = title
        self.sectionIndex = sectionIndex
        self.delegate = delegate
        self.onPlusButtonTap = onPlusButtonTap
        
        chevronButton.isHidden = !showChevron
        plusButton.isHidden = !showPlus
    }
    
    @IBAction func didTapChevron(_ sender: UIButton) {
        delegate?.didTapSeeAll(in: sectionIndex)
    }
    
    @IBAction func didTapPlus(_ sender: UIButton) {
        onPlusButtonTap?()
    }
}
