import UIKit
import SwiftData

class HistoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var historyImageView: UIImageView!
    @IBOutlet weak var specieNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var containeView: UIView!
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 1.0
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        historyImageView.image = nil
        specieNameLabel.text = nil
        dateLabel.text = nil
       
        contentView.layer.borderWidth = 1.0
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.backgroundColor = .systemBackground
    }
    
    func configureCell(historyItem: IdentificationSession) {
        contentView.backgroundColor = .systemBackground
        
        
        if let bird = historyItem.result?.bird {
            specieNameLabel.text = bird.commonName
            
            if let image = UIImage(named: bird.staticImageName) {
                historyImageView.image = image
                historyImageView.contentMode = .scaleAspectFill
            } else {
             
                historyImageView.image = UIImage(systemName: "bird.fill")
                historyImageView.tintColor = .systemGray4
                historyImageView.contentMode = .scaleAspectFit
            }
        } else {
          
            specieNameLabel.text = "Unknown Species"
            historyImageView.image = UIImage(systemName: "questionmark.circle.fill")
            historyImageView.tintColor = .systemGray4
            historyImageView.contentMode = .scaleAspectFit
        }

        historyImageView.layer.cornerRadius = 10
        historyImageView.clipsToBounds = true
        
        // 2. Format the Date
        dateLabel.text = formatDate(historyItem.observationDate)
    }
    
    func showEmptyState() {
        historyImageView.image = UIImage(systemName: "clock.arrow.circlepath")
        historyImageView.tintColor = .systemGray3
        historyImageView.contentMode = .scaleAspectFit

        specieNameLabel.text = "No history yet"
        specieNameLabel.textAlignment = .center
        specieNameLabel.textColor = .secondaryLabel

        dateLabel.text = "Start identifying birds"
        dateLabel.textAlignment = .center
        dateLabel.textColor = .tertiaryLabel
    }

    override var isSelected: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                if self.isSelected {
                    self.contentView.layer.borderWidth = 3.0 // Matches ResultCell
                    self.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                    self.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                } else {
                    self.contentView.layer.borderWidth = 1.0
                    self.contentView.layer.borderColor = UIColor.systemGray4.cgColor
                    self.contentView.backgroundColor = .systemBackground
                }
            }
        }
    }
    private func formatDate(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM yyyy"
        return outputFormatter.string(from: date)
    }
}
