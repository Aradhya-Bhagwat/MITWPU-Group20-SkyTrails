import UIKit

class HistorySectionHeaderView: UICollectionReusableView {
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var dateCapsuleView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
		dateLabel.font = .preferredFont(forTextStyle: .body)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .label

        dateCapsuleView.layer.cornerRadius = 10
        dateCapsuleView.layer.borderWidth = 1
        dateCapsuleView.clipsToBounds = true
        applyCapsuleAppearance()
    }
    
    func configure(date: String) {
        dateLabel.text = date
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        dateLabel.text = nil
        applyCapsuleAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyCapsuleAppearance()
    }

    private func applyCapsuleAppearance() {
        dateCapsuleView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        dateCapsuleView.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.2).cgColor
    }
}
