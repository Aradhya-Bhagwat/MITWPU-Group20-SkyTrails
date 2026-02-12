//
//  PageControlReusableViewCollectionReusableView.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class PageControlReusableViewCollectionReusableView: UICollectionReusableView {
    
    static let identifier = "PageControlReusableViewCollectionReusableView"
        
    @IBOutlet weak var pageControl: UIPageControl!

    override func awakeFromNib() {
        super.awakeFromNib()
        applySemanticAppearance()
        pageControl.hidesForSinglePage = true
        self.backgroundColor = .clear
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        applySemanticAppearance()
    }
    
    func configure(numberOfPages: Int, currentPage: Int) {
            pageControl.numberOfPages = numberOfPages
            pageControl.currentPage = currentPage
        }

    private func applySemanticAppearance() {
        pageControl.pageIndicatorTintColor = UIColor.systemGray4
        pageControl.currentPageIndicatorTintColor = UIColor.systemBlue
    }
}
