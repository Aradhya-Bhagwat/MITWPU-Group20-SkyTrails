import UIKit

protocol SectionHeaderDelegate: AnyObject {
    func didTapSeeAll(in section: Int)
}

class WatchlistSectionHeaderCollectionReusableView: UICollectionReusableView {
    
    static var identifier: String = "WatchlistSectionHeaderCollectionReusableView"
    
    @IBOutlet weak var sectionTitle: UILabel!
    @IBOutlet weak var seeAllButton: UIButton!
    
    weak var delegate: SectionHeaderDelegate?
    var sectionIndex: Int = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupStyle()
        setupInteraction()
    }
    
    private func setupStyle() {
        sectionTitle.font = UIFont.preferredFont(forTextStyle: .headline)
        sectionTitle.textColor = .label
        seeAllButton.isUserInteractionEnabled = false
    }
    
    private func setupInteraction() {
        self.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
        self.addGestureRecognizer(tapGesture)
    }
    
    func configure(title: String, sectionIndex: Int, showSeeAll: Bool = true, delegate: SectionHeaderDelegate?) {
        sectionTitle.text = title
        self.sectionIndex = sectionIndex
        self.delegate = delegate
        self.seeAllButton.isHidden = !showSeeAll
    }
    
    @objc private func headerTapped() {
        delegate?.didTapSeeAll(in: sectionIndex)
    }
}