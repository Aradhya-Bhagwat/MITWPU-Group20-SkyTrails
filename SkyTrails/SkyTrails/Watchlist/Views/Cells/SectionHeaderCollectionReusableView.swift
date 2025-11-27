import UIKit

	// 1. Define the protocol for communication
protocol SectionHeaderDelegate: AnyObject {
	func didTapSeeAll(in section: Int)
}

class SectionHeaderCollectionReusableView: UICollectionReusableView {
	
	static var identifier: String = "SectionHeaderCollectionReusableView"
	
	@IBOutlet weak var sectionTitle: UILabel!
	
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
	}
	
		// 3. Add gesture recognizer
	private func setupInteraction() {
			// Enable user interaction on the view itself
		self.isUserInteractionEnabled = true
		
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
		self.addGestureRecognizer(tapGesture)
	}
	
		// 4. Update configure to accept the delegate and index
	func configure(title: String, sectionIndex: Int, delegate: SectionHeaderDelegate?) {
		sectionTitle.text = title
		self.sectionIndex = sectionIndex
		self.delegate = delegate
	}
	
		// 5. Handle the tap
	@objc private func headerTapped() {
		delegate?.didTapSeeAll(in: sectionIndex)
	}
}
