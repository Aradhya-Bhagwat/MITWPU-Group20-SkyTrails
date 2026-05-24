
import UIKit

class NewsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var newsImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    
    private let textContainer = UIView()
    private let dateLabel = UILabel()
    private let sourceBadge = UIView()
    private let sourceLabel = UILabel()
    private let readMoreStack = UIStackView()
    private let readMoreLabel = UILabel()
    private let arrowIcon = UIImageView()
    
    private var imageTask: URLSessionDataTask?
    private var representedImageKey: String?
    private static let remoteImageCache = NSCache<NSString, UIImage>()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupBlogLayout()
        setupTraitChangeHandling()
        setupAppearance()
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
                self.alpha = self.isHighlighted ? 0.9 : 1.0
            }
        }
    }

    private func setupBlogLayout() {
        // 1. Structural Setup
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        textContainer.backgroundColor = .systemBackground
        containerView.addSubview(textContainer)
        
        // 2. Metadata Row (Date & Source Badge)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        dateLabel.textColor = .secondaryLabel
        textContainer.addSubview(dateLabel)
        
        sourceBadge.translatesAutoresizingMaskIntoConstraints = false
        sourceBadge.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.15)
        sourceBadge.layer.cornerRadius = 4
        textContainer.addSubview(sourceBadge)
        
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        sourceLabel.textColor = .systemTeal
        sourceBadge.addSubview(sourceLabel)
        
        // 3. Title & Summary Styling
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        textContainer.addSubview(titleLabel)
        
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 2
        textContainer.addSubview(summaryLabel)
        
        // 4. Read More Action
        readMoreStack.translatesAutoresizingMaskIntoConstraints = false
        readMoreStack.axis = .horizontal
        readMoreStack.spacing = 6
        readMoreStack.alignment = .center
        textContainer.addSubview(readMoreStack)
        
        readMoreLabel.text = "READ MORE"
        readMoreLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        readMoreLabel.textColor = .label
        
        arrowIcon.image = UIImage(systemName: "chevron.right.circle.fill")
        arrowIcon.tintColor = .label
        arrowIcon.contentMode = .scaleAspectFit
        
        readMoreStack.addArrangedSubview(readMoreLabel)
        readMoreStack.addArrangedSubview(arrowIcon)
        
        // 5. Constraints Deactivation & Activation
        newsImageView.translatesAutoresizingMaskIntoConstraints = false
        for constraint in containerView.constraints {
            constraint.isActive = false
        }
        
        NSLayoutConstraint.activate([
            // Image at the top (45% height)
            newsImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            newsImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            newsImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            newsImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.45),
            
            // Text Container takes the rest
            textContainer.topAnchor.constraint(equalTo: newsImageView.bottomAnchor),
            textContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Date (Top Left of text area)
            dateLabel.topAnchor.constraint(equalTo: textContainer.topAnchor, constant: 14),
            dateLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 16),
            
            // Source Badge (Top Right of text area)
            sourceBadge.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            sourceBadge.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -16),
            
            sourceLabel.topAnchor.constraint(equalTo: sourceBadge.topAnchor, constant: 3),
            sourceLabel.bottomAnchor.constraint(equalTo: sourceBadge.bottomAnchor, constant: -3),
            sourceLabel.leadingAnchor.constraint(equalTo: sourceBadge.leadingAnchor, constant: 8),
            sourceLabel.trailingAnchor.constraint(equalTo: sourceBadge.trailingAnchor, constant: -8),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -16),
            
            // Summary
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -16),
            
            // Read More (Bottom Right)
            readMoreStack.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor, constant: -16),
            readMoreStack.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -16),
            arrowIcon.widthAnchor.constraint(equalToConstant: 18),
            arrowIcon.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.setupAppearance()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        representedImageKey = nil
        newsImageView.image = UIImage(systemName: "photo")
    }
    
    func configure(with news: NewsItem) {
        titleLabel.text = news.title
        summaryLabel.text = news.summary
        sourceLabel.text = (news.sourceName?.isEmpty == false) ? news.sourceName!.uppercased() : "SKYTRAILS"
        
        if let pubDate = news.publishedAt, let date = isoDate(from: pubDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            dateLabel.text = formatter.string(from: date)
        } else {
            dateLabel.text = "Recent News"
        }
        
        if news.imageName.starts(with: "http"), let url = URL(string: news.imageName) {
            loadRemoteImage(from: url, cacheKey: news.imageName)
        } else if let image = UIImage(named: news.imageName) {
            newsImageView.image = image
            newsImageView.tintColor = nil
        } else {
            newsImageView.image = UIImage(systemName: "photo")
            newsImageView.tintColor = .systemGray
        }
    }

    private func isoDate(from raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private func loadRemoteImage(from url: URL, cacheKey: String) {
        representedImageKey = cacheKey
        if let cached = Self.remoteImageCache.object(forKey: cacheKey as NSString) {
            newsImageView.image = cached
            return
        }

        imageTask?.cancel()
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            Self.remoteImageCache.setObject(image, forKey: cacheKey as NSString)
            DispatchQueue.main.async {
                guard self.representedImageKey == cacheKey else { return }
                self.newsImageView.image = image
            }
        }
        imageTask?.resume()
    }
    
    private func setupAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true
        
        // Subtle border for definition (No heavy shadows as requested previously)
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = isDarkMode ? UIColor.systemGray4.cgColor : UIColor.systemGray5.cgColor
        
        layer.cornerRadius = 12
        layer.masksToBounds = false
        layer.shadowOpacity = 0 // Explicitly disable shadows
    }
}
