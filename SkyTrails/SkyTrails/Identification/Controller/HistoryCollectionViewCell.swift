import UIKit
import SwiftData

class HistoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var historyImageView: UIImageView!
    @IBOutlet weak var specieNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var containeView: UIView!

    private func applySelectionAppearance() {
        updateCellUI(isSelected: isSelected)
    }

    private func updateCellUI(isSelected: Bool) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let unselectedColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        layer.cornerRadius = 16
        layer.masksToBounds = false
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        if isSelected {
            if isDarkMode {
                contentView.layer.borderWidth = 0
                contentView.layer.borderColor = UIColor.clear.cgColor
                contentView.backgroundColor = .secondarySystemBackground
            } else {
                contentView.layer.borderWidth = 3
                contentView.layer.borderColor = UIColor.systemBlue.cgColor
                contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            }
        } else {
            contentView.layer.borderWidth = isDarkMode ? 0 : 1
            contentView.layer.borderColor = isDarkMode ? UIColor.clear.cgColor : UIColor.systemGray4.cgColor
            contentView.backgroundColor = unselectedColor
        }

        containeView.backgroundColor = contentView.backgroundColor

        if isDarkMode {
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
            layer.shadowPath = nil
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.08
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 6
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTraitChangeHandling()
        contentView.clipsToBounds = true
        applySelectionAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        historyImageView.image = nil
        specieNameLabel.text = nil
        dateLabel.text = nil
       
        applySelectionAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applySelectionAppearance()
    }
    
    func configureCell(historyItem: IdentificationSession) {
        applySelectionAppearance()
        specieNameLabel.textAlignment = .natural
        specieNameLabel.textColor = .label
        dateLabel.textAlignment = .natural
        dateLabel.textColor = .secondaryLabel
        
        if let bird = historyItem.result?.bird {
            specieNameLabel.text = bird.commonName
            
            if let image = UIImage(named: bird.staticImageName) {
                historyImageView.image = image
                historyImageView.contentMode = .scaleAspectFill
            } else {
             
                historyImageView.image = UIImage(systemName: "bird.fill")
                historyImageView.tintColor = .secondaryLabel
                historyImageView.contentMode = .scaleAspectFit
            }
        } else {
          
            specieNameLabel.text = "Unknown Species"
            historyImageView.image = UIImage(systemName: "questionmark.circle.fill")
            historyImageView.tintColor = .secondaryLabel
            historyImageView.contentMode = .scaleAspectFit
        }

        historyImageView.layer.cornerRadius = 10
        historyImageView.clipsToBounds = true
        
        // 2. Format the Date
        dateLabel.text = formatDate(historyItem.observationDate)
    }
    
    func showEmptyState() {
        historyImageView.image = UIImage(systemName: "clock.arrow.circlepath")
        historyImageView.tintColor = .tertiaryLabel
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
                self.applySelectionAppearance()
            }
        }
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySelectionAppearance()
    }

    private func formatDate(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM yyyy"
        return outputFormatter.string(from: date)
    }
}
