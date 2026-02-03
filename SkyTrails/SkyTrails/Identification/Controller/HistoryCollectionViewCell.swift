import UIKit
import SwiftData

class HistoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var historyImageView: UIImageView!
    @IBOutlet weak var specieNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset properties to default state to avoid UI bugs during scrolling
        historyImageView.image = nil
        historyImageView.tintColor = nil
        historyImageView.contentMode = .scaleAspectFill
        
        specieNameLabel.text = nil
        specieNameLabel.textAlignment = .left
        specieNameLabel.font = .systemFont(ofSize: 16, weight: .bold) // Default font
        
        dateLabel.text = nil
        dateLabel.textAlignment = .left
        
        contentView.backgroundColor = .white
        contentView.layer.borderWidth = 0
    }
    
    func configureCell(historyItem: IdentificationSession) {
        contentView.backgroundColor = .white
        
        
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
                    self.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
                    self.contentView.layer.borderWidth = 1.5
                    self.contentView.layer.borderColor = UIColor.systemBlue.cgColor
                } else {
                    self.contentView.backgroundColor = .white
                    self.contentView.layer.borderWidth = 0
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
