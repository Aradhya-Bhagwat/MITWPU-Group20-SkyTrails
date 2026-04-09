
import UIKit

class NewsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var newsImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    private let sourceLabel = UILabel()
    
    private var gradientLayer: CAGradientLayer?
    private var imageTask: URLSessionDataTask?
    private var representedImageKey: String?
    private static let remoteImageCache = NSCache<NSString, UIImage>()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupSourceLabel()
        setupTraitChangeHandling()
        setupAppearance()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        setupAppearance()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard newsImageView != nil else { return }
        applyGradientLayer()
        if traitCollection.userInterfaceStyle != .dark {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        representedImageKey = nil
        sourceLabel.text = nil
        newsImageView.image = UIImage(systemName: "photo")
        newsImageView.tintColor = .systemGray
    }
    
    func configure(with news: NewsItem) {
        titleLabel.text = news.title
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 3
        
        summaryLabel.text = news.summary
        summaryLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        summaryLabel.textColor = .white.withAlphaComponent(0.9)
        summaryLabel.numberOfLines = 3
        sourceLabel.text = makeSourceText(news: news)
        
        if news.imageName.starts(with: "http"), let url = URL(string: news.imageName) {
            loadRemoteImage(from: url, cacheKey: news.imageName)
        } else if let image = UIImage(named: news.imageName) {
            newsImageView.image = image
            newsImageView.tintColor = nil
        } else {
            newsImageView.image = UIImage(systemName: "photo")
            newsImageView.tintColor = .systemGray
        }
        
        containerView.bringSubviewToFront(titleLabel)
        containerView.bringSubviewToFront(summaryLabel)
        containerView.bringSubviewToFront(sourceLabel)
    }

    private func setupSourceLabel() {
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        sourceLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        sourceLabel.numberOfLines = 1
        sourceLabel.textAlignment = .left
        containerView.addSubview(sourceLabel)

        NSLayoutConstraint.activate([
            sourceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            sourceLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -14),
            sourceLabel.bottomAnchor.constraint(equalTo: summaryLabel.topAnchor, constant: -6)
        ])
    }

    private func makeSourceText(news: NewsItem) -> String {
        let source = news.sourceName.flatMap { $0.isEmpty ? nil : $0 } ?? "SkyTrails"

        guard let publishedAt = news.publishedAt,
              let date = isoDate(from: publishedAt) else {
            return "Source: \(source)"
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d MMM yyyy"
        return "Source: \(source) • \(formatter.string(from: date))"
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
            newsImageView.tintColor = nil
            return
        }

        newsImageView.image = UIImage(systemName: "photo")
        newsImageView.tintColor = .systemGray

        imageTask?.cancel()
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let image = UIImage(data: data) else { return }

            Self.remoteImageCache.setObject(image, forKey: cacheKey as NSString)
            DispatchQueue.main.async {
                guard self.representedImageKey == cacheKey else { return }
                self.newsImageView.image = image
                self.newsImageView.tintColor = nil
            }
        }
        imageTask?.resume()
    }
    
    private func applyGradientLayer() {
        
        gradientLayer?.removeFromSuperlayer()
        let gradient = CAGradientLayer()
        self.gradientLayer = gradient
        
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.2).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        
        gradient.locations = [0.5, 1.0]
        gradient.frame = newsImageView.bounds
        
        newsImageView.layer.insertSublayer(gradient, at: 0)
    }

    private func setupAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = cardColor
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        layer.cornerRadius = 16
        layer.masksToBounds = false

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
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        }
    }

}
