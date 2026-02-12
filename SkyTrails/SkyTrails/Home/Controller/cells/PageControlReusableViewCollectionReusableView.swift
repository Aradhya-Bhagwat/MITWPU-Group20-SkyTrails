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
        setupTraitChangeHandling()
        applySemanticAppearance()
        pageControl.hidesForSinglePage = true
        self.backgroundColor = .clear
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
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
