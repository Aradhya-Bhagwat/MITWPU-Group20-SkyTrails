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
        pageControl.pageIndicatorTintColor = UIColor.systemGray4
        pageControl.currentPageIndicatorTintColor = UIColor.black
        pageControl.hidesForSinglePage = true
        self.backgroundColor = .clear
    }
    
    func configure(numberOfPages: Int, currentPage: Int) {
            pageControl.numberOfPages = numberOfPages
            pageControl.currentPage = currentPage
        }
}
