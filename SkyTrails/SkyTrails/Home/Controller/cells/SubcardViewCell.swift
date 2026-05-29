
import UIKit

class SubcardViewCell: UICollectionViewCell {
    
    static let identifier = "SubcardViewCell"
    
    // MARK: - UI Components
    
    private let mainContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 22
        v.layer.masksToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let birdImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.backgroundColor = .systemGray5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let gradientLayer: CAGradientLayer = {
        let l = CAGradientLayer()
        l.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.85).cgColor]
        l.locations = [0.35, 1.0]
        return l
    }()
    
    private let statusBadge: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGreen.withAlphaComponent(0.85)
        v.layer.cornerRadius = 10
        // Add shadow for elevation
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.25
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 4
        v.layer.masksToBounds = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let statusBadgeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .bold)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let heartButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "heart"), for: .normal)
        b.tintColor = .white
        // Add shadow for elevation
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.3
        b.layer.shadowOffset = CGSize(width: 0, height: 2)
        b.layer.shadowRadius = 4
        b.layer.masksToBounds = false
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .bold)
        l.textColor = .white // White text for contrast on dark blur
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameBlurBackground: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        v.layer.cornerRadius = 14
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var currentImageTask: Task<Void, Never>?
    private var isFavorite = false

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentView.addSubview(mainContainer)
        mainContainer.addSubview(birdImageView)
        mainContainer.layer.addSublayer(gradientLayer)
        
        mainContainer.addSubview(statusBadge)
        statusBadge.addSubview(statusBadgeLabel)
        mainContainer.addSubview(heartButton)
        
        mainContainer.addSubview(nameBlurBackground)
        nameBlurBackground.contentView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            birdImageView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            birdImageView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            birdImageView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            birdImageView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            
            statusBadge.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 12),
            statusBadge.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 12),
            statusBadge.heightAnchor.constraint(equalToConstant: 24),
            
            statusBadgeLabel.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 10),
            statusBadgeLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -10),
            statusBadgeLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            
            heartButton.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 14),
            heartButton.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor, constant: -14),
            heartButton.widthAnchor.constraint(equalToConstant: 24),
            heartButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Name Blur Background
            nameBlurBackground.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -12),
            nameBlurBackground.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 12),
            nameBlurBackground.trailingAnchor.constraint(lessThanOrEqualTo: mainContainer.trailingAnchor, constant: -12),
            nameBlurBackground.heightAnchor.constraint(equalToConstant: 28),
            
            // Name Label within Blur
            nameLabel.leadingAnchor.constraint(equalTo: nameBlurBackground.contentView.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: nameBlurBackground.contentView.trailingAnchor, constant: -10),
            nameLabel.centerYAnchor.constraint(equalTo: nameBlurBackground.contentView.centerYAnchor)
        ])
        
        heartButton.addTarget(self, action: #selector(didTapHeart), for: .touchUpInside)
    }
    
    @objc private func didTapHeart() {
        isFavorite.toggle()
        let color: UIColor = isFavorite ? .systemPink : .white
        let iconName = isFavorite ? "heart.fill" : "heart"
        
        UIView.animate(withDuration: 0.2, animations: {
            self.heartButton.tintColor = color
            self.heartButton.setImage(UIImage(systemName: iconName), for: .normal)
            self.heartButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.heartButton.transform = .identity
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = mainContainer.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentImageTask?.cancel()
        currentImageTask = nil
        birdImageView.image = nil
        isFavorite = false
        heartButton.tintColor = .white
        heartButton.setImage(UIImage(systemName: "heart"), for: .normal)
    }

    func configure(with birdData: BirdSpeciesDisplay) {
        nameLabel.text = birdData.birdName
        
        let tag: String
        let color: UIColor
        let prob = birdData.sightabilityPercent
        
        
        if prob >= 70 {
            tag = "Common"
            color = .systemGreen
        } else if prob >= 40 {
            tag = "Uncommon"
            color = .systemBlue
        } else if prob >= 15 {
            tag = "Rare"
            color = .systemOrange
        } else {
            tag = "Very Rare"
            color = .systemRed
        }
        
        statusBadgeLabel.text = tag
        statusBadge.backgroundColor = color.withAlphaComponent(0.85)
        
        currentImageTask?.cancel()
        currentImageTask = Task { @MainActor in
            let image = await ImageService.shared.image(for: birdData.birdImageName)
            if !Task.isCancelled {
                self.birdImageView.image = image
            }
        }
    }
    
    
}
