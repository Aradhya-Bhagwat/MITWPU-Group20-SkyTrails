import UIKit

	// 1. Define the protocol for communication
protocol SectionHeaderDelegate: AnyObject {
	func didTapSeeAll(in section: Int)
}

class WatchlistSectionHeaderCollectionReusableView: UICollectionReusableView {
	
	static var identifier: String = "WatchlistSectionHeaderCollectionReusableView"
	
	@IBOutlet weak var sectionTitle: UILabel!
	@IBOutlet weak var seeAllButton: UIButton!
	
		// 2. Add properties to hold the delegate and index
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
        // Ensure button handles tap if not using the whole view gesture
        seeAllButton.isUserInteractionEnabled = false // Let the view gesture handle it, or true if we want specific target
	}
	
		// 3. Add gesture recognizer
	private func setupInteraction() {
			// Enable user interaction on the view itself
		self.isUserInteractionEnabled = true
		
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
		self.addGestureRecognizer(tapGesture)
	}
	
		// 4. Update configure to accept the delegate and index
    func configure(title: String, sectionIndex: Int, showSeeAll: Bool = true, delegate: SectionHeaderDelegate?) {
		sectionTitle.text = title
		self.sectionIndex = sectionIndex
		self.delegate = delegate
        self.seeAllButton.isHidden = !showSeeAll
	}
	
		// 5. Handle the tap
	@objc private func headerTapped() {
		delegate?.didTapSeeAll(in: sectionIndex)
	}
}
