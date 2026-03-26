import UIKit

class HistorySectionHeaderView: UICollectionReusableView {
    
    @IBOutlet weak var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        dateLabel.font = .preferredFont(forTextStyle: .title2)
        dateLabel.textColor = .label
    }
    
    func configure(date: String) {
        dateLabel.text = date
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        dateLabel.text = nil
    }
}
