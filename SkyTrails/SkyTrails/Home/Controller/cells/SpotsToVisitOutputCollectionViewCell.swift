
import UIKit

final class SpotsToVisitOutputCollectionViewCell: UICollectionViewCell {
    static let identifier = "SpotsToVisitOutputCollectionViewCell"

    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var compactCardView: UIView!
    @IBOutlet weak var wideCardView: UIView!

    @IBOutlet weak var compactBirdImageView: UIImageView!
    @IBOutlet weak var compactBirdNameLabel: UILabel!
    @IBOutlet weak var compactBadgeIconImageView: UIImageView!
    @IBOutlet weak var compactBadgeTitleLabel: UILabel!
    @IBOutlet weak var compactBadgeSubtitleLabel: UILabel!
    @IBOutlet weak var compactSightabilityLabel: UILabel!

    @IBOutlet weak var wideBirdImageView: UIImageView!
    @IBOutlet weak var wideBirdNameLabel: UILabel!
    @IBOutlet weak var wideBadgeIconImageView: UIImageView!
    @IBOutlet weak var wideBadgeTitleLabel: UILabel!
    @IBOutlet weak var wideBadgeSubtitleLabel: UILabel!
    @IBOutlet weak var wideSightabilityLabel: UILabel!

    private var showsWideCard: Bool?
    private var isCardSelected = false
    private var currentStatusColor: UIColor = .systemBlue
    private var currentStatusTitle: String = ""
    private var currentStatusSubtitle: String = ""
    private var currentProbability: Int = 0

    private var actionButtonsContainer: UIStackView?
    private var currentPrediction: FinalPredictionResult?
    private var hasConfiguredLayoutBehavior = false
    private var hasInstalledCompactTopRowFix = false
    private var compactBadgeContainerWidthConstraint: NSLayoutConstraint?
    private var compactBadgeContainerHeightConstraint: NSLayoutConstraint?
    private var wideBadgeContainerWidthConstraint: NSLayoutConstraint?
    private var wideBadgeContainerHeightConstraint: NSLayoutConstraint?
    
    private let graphView: SightabilityGraphView = {
        let v = SightabilityGraphView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()
    
    private let wideCircularView: CircularSightabilityView = {
        let v = CircularSightabilityView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let compactCircularView: CircularSightabilityView = {
        let v = CircularSightabilityView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let separatorView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGray6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let verticalSeparatorView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGray6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let calendarContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        v.layer.cornerRadius = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let calendarIcon: UIImageView = {
        let v = UIImageView(image: UIImage(systemName: "calendar"))
        v.tintColor = .systemGreen
        v.contentMode = .scaleAspectFit
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let sightabilityTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Sightability"
        l.font = .systemFont(ofSize: 12, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let sightabilityStatusLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = .systemGreen
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var weekInfoStack: UIStackView = {
        let v = UIStackView(arrangedSubviews: [wideBadgeTitleLabel, wideSightabilityLabel])
        v.axis = .vertical
        v.spacing = 0
        v.alignment = .trailing
        return v
    }()

    private lazy var sightabilityInfoStack: UIStackView = {
        let v = UIStackView(arrangedSubviews: [sightabilityTitleLabel, sightabilityStatusLabel])
        v.axis = .vertical
        v.spacing = 0
        v.alignment = .trailing
        return v
    }()

    private lazy var premiumInfoRowStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [calendarContainer, weekInfoStack, verticalSeparatorView, sightabilityInfoStack, wideCircularView])
        s.axis = .horizontal
        s.spacing = 12
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    var onTapBirdPath: ((FinalPredictionResult) -> Void)?
    var onTapWatchlist: ((FinalPredictionResult) -> Void)?
    
    private var currentImageTask: Task<Void, Never>?


    override func awakeFromNib() {
        setupLayoutBehavior()
        setupPremiumWideLayout()
        setupAppearance()
        updateCardVariant()
        setupActionButtons()
    }

    private func setupPremiumWideLayout() {
        // Clear existing wideCardView subviews to build fresh
        wideCardView.subviews.forEach { $0.removeFromSuperview() }
        
        wideCardView.addSubview(wideBirdImageView)
        wideCardView.addSubview(wideBirdNameLabel)
        wideCardView.addSubview(wideBadgeSubtitleLabel)
        
        // Setup calendar icon layout within its container before adding stack
        calendarContainer.addSubview(calendarIcon)
        NSLayoutConstraint.activate([
            calendarIcon.centerXAnchor.constraint(equalTo: calendarContainer.centerXAnchor),
            calendarIcon.centerYAnchor.constraint(equalTo: calendarContainer.centerYAnchor),
            calendarIcon.widthAnchor.constraint(equalToConstant: 16),
            calendarIcon.heightAnchor.constraint(equalToConstant: 16),
            calendarContainer.widthAnchor.constraint(equalToConstant: 30),
            calendarContainer.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Add the main premium info stack
        wideCardView.addSubview(premiumInfoRowStack)
        wideCardView.addSubview(graphView)
        
        wideBirdImageView.translatesAutoresizingMaskIntoConstraints = false
        wideBirdNameLabel.translatesAutoresizingMaskIntoConstraints = false
        wideBadgeSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure Stack constraints
        NSLayoutConstraint.activate([
            verticalSeparatorView.widthAnchor.constraint(equalToConstant: 1),
            verticalSeparatorView.heightAnchor.constraint(equalToConstant: 22),
            wideCircularView.widthAnchor.constraint(equalToConstant: 30),
            wideCircularView.heightAnchor.constraint(equalToConstant: 30)
        ])

        NSLayoutConstraint.activate([
            // Bird Image
            wideBirdImageView.leadingAnchor.constraint(equalTo: wideCardView.leadingAnchor, constant: 12),
            wideBirdImageView.topAnchor.constraint(equalTo: wideCardView.topAnchor, constant: 12),
            wideBirdImageView.bottomAnchor.constraint(equalTo: wideCardView.bottomAnchor, constant: -12),
            wideBirdImageView.widthAnchor.constraint(equalTo: wideCardView.heightAnchor, constant: -24),
            
            // Info Row (Anchored to Top Right)
            premiumInfoRowStack.topAnchor.constraint(equalTo: wideCardView.topAnchor, constant: 14),
            premiumInfoRowStack.trailingAnchor.constraint(equalTo: wideCardView.trailingAnchor, constant: -14),
            
            // Bird Name (BELOW or BESIDE info row depending on space)
            wideBirdNameLabel.topAnchor.constraint(equalTo: wideCardView.topAnchor, constant: 14),
            wideBirdNameLabel.leadingAnchor.constraint(equalTo: wideBirdImageView.trailingAnchor, constant: 20),
            wideBirdNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: premiumInfoRowStack.leadingAnchor, constant: -12),
            
            // Subtitle (Expected/Recently spotted)
            wideBadgeSubtitleLabel.topAnchor.constraint(equalTo: wideBirdNameLabel.bottomAnchor, constant: 4),
            wideBadgeSubtitleLabel.leadingAnchor.constraint(equalTo: wideBirdNameLabel.leadingAnchor),
            
            // Graph View
            graphView.topAnchor.constraint(equalTo: wideBadgeSubtitleLabel.bottomAnchor, constant: 6),
            graphView.leadingAnchor.constraint(equalTo: wideBirdImageView.trailingAnchor, constant: 12),
            graphView.trailingAnchor.constraint(equalTo: wideCardView.trailingAnchor, constant: -12),
            graphView.bottomAnchor.constraint(equalTo: wideCardView.bottomAnchor, constant: -4)
        ])
        
        // Ensure priorities to prevent compression of critical info
        wideBirdNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        premiumInfoRowStack.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func setupGraphView() {
        // Legacy setup replaced by setupPremiumWideLayout
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentImageTask?.cancel()
        currentImageTask = nil
        compactBirdImageView.image = UIImage(systemName: "bird.fill")
        wideBirdImageView.image = UIImage(systemName: "bird.fill")
    }


    override func layoutSubviews() {
        super.layoutSubviews()
        installCompactTopRowFixIfNeeded()
        updateScaledLayout()
        updateCardVariant()
        applyBadgeIconStyle()
    }

    private func setupAppearance() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 24
        contentView.layer.masksToBounds = false

        compactCardView.layer.cornerRadius = 20
        wideCardView.layer.cornerRadius = 24
        compactCardView.layer.masksToBounds = false
        wideCardView.layer.masksToBounds = false
        contentView.clipsToBounds = false
        clipsToBounds = false
        
        compactCardView.backgroundColor = .systemBackground
        wideCardView.backgroundColor = .systemBackground

        // Apply premium shadow to the cards
        [compactCardView, wideCardView].forEach { card in
            card?.layer.shadowColor = UIColor.black.cgColor
            card?.layer.shadowOpacity = 0.08
            card?.layer.shadowOffset = CGSize(width: 0, height: 8)
            card?.layer.shadowRadius = 16
        }

        compactBirdImageView.layer.cornerRadius = 16
        wideBirdImageView.layer.cornerRadius = 20
        compactBirdImageView.clipsToBounds = true
        wideBirdImageView.clipsToBounds = true

        compactBirdNameLabel.textColor = .label
        wideBirdNameLabel.textColor = .label
        compactBadgeTitleLabel.textColor = .label
        wideBadgeTitleLabel.textColor = .label
        compactBadgeSubtitleLabel.textColor = .secondaryLabel
        wideBadgeSubtitleLabel.textColor = .secondaryLabel
        compactSightabilityLabel.textColor = .secondaryLabel
        wideSightabilityLabel.textColor = .secondaryLabel
        
        setupCompactPremiumLayout()
    }

    private let compactCalendarIcon: UIImageView = {
        let v = UIImageView(image: UIImage(systemName: "calendar"))
        v.tintColor = .systemGreen
        v.contentMode = .scaleAspectFit
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var compactWeekInfoStack: UIStackView = {
        let v = UIStackView(arrangedSubviews: [compactBadgeTitleLabel, compactSightabilityLabel])
        v.axis = .vertical
        v.spacing = 0
        v.alignment = .trailing
        return v
    }()

    private func setupCompactPremiumLayout() {
        // Clear and rebuild compactCardView to match premium theme
        compactCardView.subviews.forEach { $0.removeFromSuperview() }
        
        compactCardView.addSubview(compactBirdImageView)
        compactCardView.addSubview(compactBirdNameLabel)
        compactCardView.addSubview(compactBadgeSubtitleLabel)
        compactCardView.addSubview(compactCircularView)
        compactCardView.addSubview(compactCalendarIcon)
        compactCardView.addSubview(compactBadgeTitleLabel)
        
        compactBirdImageView.translatesAutoresizingMaskIntoConstraints = false
        compactBirdNameLabel.translatesAutoresizingMaskIntoConstraints = false
        compactBadgeSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        compactCircularView.translatesAutoresizingMaskIntoConstraints = false
        compactBadgeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Bird Image (Left side, fixed square)
            compactBirdImageView.leadingAnchor.constraint(equalTo: compactCardView.leadingAnchor, constant: 10),
            compactBirdImageView.centerYAnchor.constraint(equalTo: compactCardView.centerYAnchor),
            compactBirdImageView.widthAnchor.constraint(equalToConstant: 72),
            compactBirdImageView.heightAnchor.constraint(equalToConstant: 72),
            
            // Circular Progress (Top Right)
            compactCircularView.topAnchor.constraint(equalTo: compactCardView.topAnchor, constant: 12),
            compactCircularView.trailingAnchor.constraint(equalTo: compactCardView.trailingAnchor, constant: -12),
            compactCircularView.widthAnchor.constraint(equalToConstant: 28),
            compactCircularView.heightAnchor.constraint(equalToConstant: 28),
            
            // Bird Name (Top Left of content area)
            compactBirdNameLabel.topAnchor.constraint(equalTo: compactCardView.topAnchor, constant: 12),
            compactBirdNameLabel.leadingAnchor.constraint(equalTo: compactBirdImageView.trailingAnchor, constant: 12),
            compactBirdNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: compactCircularView.leadingAnchor, constant: -8),
            
            // Calendar Icon (Below Name)
            compactCalendarIcon.topAnchor.constraint(equalTo: compactBirdNameLabel.bottomAnchor, constant: 6),
            compactCalendarIcon.leadingAnchor.constraint(equalTo: compactBirdNameLabel.leadingAnchor),
            compactCalendarIcon.widthAnchor.constraint(equalToConstant: 12),
            compactCalendarIcon.heightAnchor.constraint(equalToConstant: 12),
            
            // Week Info Title (May 4th week)
            compactBadgeTitleLabel.centerYAnchor.constraint(equalTo: compactCalendarIcon.centerYAnchor),
            compactBadgeTitleLabel.leadingAnchor.constraint(equalTo: compactCalendarIcon.trailingAnchor, constant: 4),
            compactBadgeTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: compactCardView.trailingAnchor, constant: -12),
            
            // Subtitle (Expected/Recently spotted - Bottom row)
            compactBadgeSubtitleLabel.topAnchor.constraint(equalTo: compactCalendarIcon.bottomAnchor, constant: 6),
            compactBadgeSubtitleLabel.leadingAnchor.constraint(equalTo: compactBirdNameLabel.leadingAnchor),
            compactBadgeSubtitleLabel.trailingAnchor.constraint(equalTo: compactCardView.trailingAnchor, constant: -12)
        ])
        
        // Refine fonts and visibility
        compactBirdNameLabel.font = .systemFont(ofSize: 15, weight: .bold)
        compactBadgeTitleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        compactBadgeSubtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        compactSightabilityLabel.isHidden = true // Hide date range in compact to prevent crowding
    }

    private func setupActionButtons() {
        guard actionButtonsContainer == nil else { return }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true

        let watchlistBtn = createActionButton(title: "Add to Watchlist")
        watchlistBtn.addTarget(self, action: #selector(didTapWatchlist), for: .touchUpInside)
        let pathBtn = createActionButton(title: "Predict Species")
        pathBtn.addTarget(self, action: #selector(didTapPath), for: .touchUpInside)

        stack.addArrangedSubview(watchlistBtn)
        stack.addArrangedSubview(pathBtn)

        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)
        wrapper.isHidden = true
        wrapper.alpha = 0
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: 0),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])

        mainStackView.addArrangedSubview(wrapper)
        mainStackView.axis = .vertical
        mainStackView.sendSubviewToBack(wrapper)
        
        self.actionButtonsContainer = stack
    }

    private func createActionButton(title: String, systemName: String? = nil, imageName: String? = nil) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)

        if let systemName = systemName {
            button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        } else if let imageName = imageName {
            button.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }

        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.semanticContentAttribute = .forceLeftToRight
        button.contentHorizontalAlignment = .center
   
        button.tintColor = .systemBlue
        button.backgroundColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark 
                ? UIColor(white: 0.15, alpha: 1.0) 
                : .systemBackground
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 44),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        button.layer.cornerRadius = 22
        
        // Use a consistent shadow that works in both modes
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.layer.masksToBounds = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        return button
    }

    private func setupLayoutBehavior() {
        guard !hasConfiguredLayoutBehavior else { return }
        hasConfiguredLayoutBehavior = true

        compactBirdNameLabel.numberOfLines = 1
        compactBirdNameLabel.lineBreakMode = .byTruncatingTail
        compactBirdNameLabel.adjustsFontSizeToFitWidth = true
        compactBirdNameLabel.minimumScaleFactor = 0.85
        compactBirdNameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        compactBirdNameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        compactBirdNameLabel.textAlignment = .left

        wideBirdNameLabel.numberOfLines = 1
        wideBirdNameLabel.lineBreakMode = .byTruncatingTail
        wideBirdNameLabel.adjustsFontSizeToFitWidth = true
        wideBirdNameLabel.minimumScaleFactor = 0.9
        wideBirdNameLabel.textAlignment = .left

        [compactSightabilityLabel, wideSightabilityLabel].forEach { label in
            label?.numberOfLines = 1
            label?.lineBreakMode = .byTruncatingTail
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.72
            label?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label?.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        compactSightabilityLabel.textAlignment = .left
        wideSightabilityLabel.textAlignment = .right

        [compactBadgeTitleLabel, compactBadgeSubtitleLabel, wideBadgeTitleLabel, wideBadgeSubtitleLabel].forEach { label in
            label?.numberOfLines = 1
            label?.lineBreakMode = .byTruncatingTail
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.82
        }

        compactBadgeTitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        compactBadgeSubtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        wideBadgeTitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        wideBadgeSubtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        if let compactBadgeContainer = compactBadgeIconImageView.superview {
            compactBadgeContainer.translatesAutoresizingMaskIntoConstraints = false
            let width = compactBadgeContainer.widthAnchor.constraint(equalToConstant: 42)
            let height = compactBadgeContainer.heightAnchor.constraint(equalToConstant: 42)
            width.priority = .required
            height.priority = .required
            NSLayoutConstraint.activate([width, height])
            compactBadgeContainerWidthConstraint = width
            compactBadgeContainerHeightConstraint = height
        }

        if let wideBadgeContainer = wideBadgeIconImageView.superview {
            wideBadgeContainer.translatesAutoresizingMaskIntoConstraints = false
            let width = wideBadgeContainer.widthAnchor.constraint(equalToConstant: 28)
            let height = wideBadgeContainer.heightAnchor.constraint(equalToConstant: 28)
            width.priority = .required
            height.priority = .required
            NSLayoutConstraint.activate([width, height])
            wideBadgeContainerWidthConstraint = width
            wideBadgeContainerHeightConstraint = height
        }
    }

    private func installCompactTopRowFixIfNeeded() {
        guard !hasInstalledCompactTopRowFix else { return }
        
        // Safely check all required views exist and have the expected hierarchy
        guard let nameLabel = compactBirdNameLabel,
              let sightLabel = compactSightabilityLabel,
              let badgeIcon = compactBadgeIconImageView,
              let statusContainer = badgeIcon.superview?.superview,
              nameLabel.superview === compactCardView,
              sightLabel.superview === compactCardView else {
            return
        }

        hasInstalledCompactTopRowFix = true

        for constraint in compactCardView.constraints {
            let first = constraint.firstItem as AnyObject?
            let second = constraint.secondItem as AnyObject?
            let touchesCompactSightability = first === sightLabel || second === sightLabel
            let touchesCompactImage = first === compactBirdImageView || second === compactBirdImageView
            let touchesCompactBirdName = first === nameLabel || second === nameLabel
            let touchesCompactStatusContainer = first === statusContainer || second === statusContainer

            if touchesCompactSightability && touchesCompactImage && constraint.firstAttribute == .leading {
                constraint.isActive = false
            }

            if touchesCompactSightability && constraint.firstAttribute == .top {
                constraint.isActive = false
            }

            if touchesCompactSightability && touchesCompactBirdName && constraint.firstAttribute == .trailing {
                constraint.isActive = false
            }

            if touchesCompactStatusContainer && constraint.firstAttribute == .centerY {
                constraint.isActive = false
            }
        }

        NSLayoutConstraint.activate([
            sightLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            sightLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            sightLabel.trailingAnchor.constraint(lessThanOrEqualTo: compactCardView.trailingAnchor, constant: -12),
            statusContainer.topAnchor.constraint(equalTo: sightLabel.bottomAnchor, constant: 14)
        ])
    }

    private func updateCardVariant() {
        let shouldShowWide = bounds.width >= 450
        if let current = showsWideCard, current == shouldShowWide {
            return
        }

        showsWideCard = shouldShowWide
        compactCardView.isHidden = shouldShowWide
        wideCardView.isHidden = !shouldShowWide
        mainStackView.layoutIfNeeded()
    }

    func configure(prediction: FinalPredictionResult, yearlyProbabilities: [Int]) {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        graphView.currentWeek = currentWeek
        if yearlyProbabilities.isEmpty {
            graphView.isLoading = true
            graphView.scores = []
        } else {
            graphView.isLoading = false
            graphView.scores = yearlyProbabilities
        }
        self.currentPrediction = prediction
        
        currentImageTask?.cancel()
        compactBirdImageView.image = UIImage(systemName: "bird.fill")
        wideBirdImageView.image = UIImage(systemName: "bird.fill")

        currentImageTask = Task { @MainActor in
            let image = await ImageService.shared.image(for: prediction.imageName)
            if !Task.isCancelled {
                let finalImage = image ?? UIImage(systemName: "bird.fill")
                self.compactBirdImageView.image = finalImage
                self.wideBirdImageView.image = finalImage
            }
        }


        compactBirdNameLabel.text = prediction.birdName
        wideBirdNameLabel.text = prediction.birdName

        currentStatusTitle = prediction.weekNumber ?? "Week \(currentWeek)"
        currentStatusSubtitle = prediction.residencyStatus ?? "Recently spotted"
        currentStatusColor = statusText(for: prediction.spottingProbability).color
        currentProbability = prediction.spottingProbability
        
        // Populate Wide UI details
        wideCircularView.probability = prediction.spottingProbability
        wideCircularView.setStrokeColor(currentStatusColor)
        compactCircularView.probability = prediction.spottingProbability
        compactCircularView.setStrokeColor(currentStatusColor)
        
        sightabilityStatusLabel.text = statusText(for: prediction.spottingProbability).title + " chance"
        sightabilityStatusLabel.textColor = currentStatusColor
        
        graphView.lineColor = currentStatusColor
        
        // Date range calculation
        if let weekNum = Int(currentStatusTitle.replacingOccurrences(of: "Week ", with: "")) {
            wideSightabilityLabel.text = dateRangeForWeek(weekNum)
        } else {
            wideSightabilityLabel.text = dateRangeForWeek(currentWeek)
        }

        applyScaledTexts()
        applyBadgeIconStyle()

        applySelectionStyle(animated: false)
    }

    private func dateRangeForWeek(_ week: Int) -> String {
        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = Calendar.current.component(.yearForWeekOfYear, from: Date())
        components.weekday = 1 // Sunday
        
        guard let startOfWeek = Calendar.current.date(from: components),
              let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startOfWeek)) – \(formatter.string(from: endOfWeek))"
    }

    @objc private func didTapPath() {
        guard let prediction = currentPrediction else { return }
        onTapBirdPath?(prediction)
    }

    @objc private func didTapWatchlist() {
        guard let prediction = currentPrediction else { return }
        onTapWatchlist?(prediction)
    }

    func setCardSelected(_ selected: Bool, animated: Bool = false) {
        isCardSelected = selected
        applySelectionStyle(animated: animated)
    }

    private func statusText(for probability: Int) -> (title: String, subtitle: String, color: UIColor) {
        let color = colorForSightability(probability)
        switch probability {
        case 75...100:
            return ("High", "Likely Today", color)
        case 50..<75:
            return ("Moderate", "Watch Nearby", color)
        case 25..<50:
            return ("Fair", "Occasional", color)
        default:
            return ("Low", "Rare Chance", color)
        }
    }

    private func applySelectionStyle(animated: Bool) {
        let borderColor = isCardSelected ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        let borderWidth: CGFloat = isCardSelected ? 2 : 0
        
        let animations = {
            self.compactCardView.layer.borderColor = borderColor
            self.compactCardView.layer.borderWidth = borderWidth
            self.wideCardView.layer.borderColor = borderColor
            self.wideCardView.layer.borderWidth = borderWidth
            
            if let container = self.actionButtonsContainer?.superview {
                if self.isCardSelected {
                    container.alpha = 1
                    container.transform = .identity
                    container.isHidden = false
                    self.actionButtonsContainer?.isHidden = false
                } else {
                    container.alpha = 0
                    container.transform = CGAffineTransform(translationX: 0, y: -10)
                    container.isHidden = true
                }
            }
            self.mainStackView.layoutIfNeeded()
        }

        if animated {
            if isCardSelected, let container = actionButtonsContainer?.superview {
                container.transform = CGAffineTransform(translationX: 0, y: -20)
                container.alpha = 0
            }
            
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: animations,
                completion: nil
            )
        } else {
            animations()
        }
    }

    private func styleBadgeIconContainer(_ imageView: UIImageView, color: UIColor) {
        guard let container = imageView.superview else { return }
        container.layoutIfNeeded()
        container.backgroundColor = color.withAlphaComponent(0.2)
        let side = min(container.bounds.width, container.bounds.height)
        if side > 0 {
            container.layer.cornerRadius = side / 2
            container.clipsToBounds = true
        }
    }

    private func updateScaledLayout() {
        let isWide = bounds.width >= 450
        let cardView = isWide ? wideCardView : compactCardView
        let currentWidth = max(1, cardView?.bounds.width ?? bounds.width)
        let titleScaleWidth = currentWidth * (18.0 / 200.0)
        let bodyScaleWidth = currentWidth * (12.0 / 200.0)
        let sightabilityScaleWidth = currentWidth * (13.5 / 200.0)
        let titleSize = isWide
            ? min(max(titleScaleWidth, 22), 32)
            : min(max(titleScaleWidth, 17), 20)
        let bodySize = isWide
            ? min(max(bodyScaleWidth, 17), 20)
            : min(max(bodyScaleWidth, 11), 13.5)
        let sightabilitySize = isWide
            ? min(max(sightabilityScaleWidth, 13), 16)
            : min(max(sightabilityScaleWidth, 12.5), 15.5)

        compactBirdNameLabel?.font = .systemFont(ofSize: titleSize, weight: .semibold)
        wideBirdNameLabel?.font = .systemFont(ofSize: titleSize, weight: .bold)

        compactBadgeTitleLabel?.font = .systemFont(ofSize: bodySize, weight: .semibold)
        compactBadgeSubtitleLabel?.font = .systemFont(ofSize: bodySize, weight: .regular)
        
        wideBadgeSubtitleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        wideBadgeTitleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        wideSightabilityLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        
        compactSightabilityLabel?.font = .systemFont(ofSize: sightabilitySize, weight: .medium)

        compactBadgeContainerWidthConstraint?.constant = min(max(bodySize * 2.9, 36), 44)
        compactBadgeContainerHeightConstraint?.constant = compactBadgeContainerWidthConstraint?.constant ?? 42
        wideBadgeContainerWidthConstraint?.constant = min(max(bodySize * 2.2, 38), 46)
        wideBadgeContainerHeightConstraint?.constant = wideBadgeContainerWidthConstraint?.constant ?? 28

        applyScaledTexts()
    }

    private func applyScaledTexts() {
        if let compactTitle = compactBadgeTitleLabel { compactTitle.text = currentStatusTitle }
        if let compactSubtitle = compactBadgeSubtitleLabel { compactSubtitle.text = currentStatusSubtitle }
        
        if let wideTitle = wideBadgeTitleLabel { wideTitle.text = currentStatusTitle }
        if let wideSubtitle = wideBadgeSubtitleLabel { wideSubtitle.text = currentStatusSubtitle }
        
        if let compactSight = compactSightabilityLabel {
            let sightabilityAttr = attributedSightabilityText(
                probability: currentProbability,
                font: compactSight.font
            )
            compactSight.attributedText = sightabilityAttr
        }
    }

    private func colorForSightability(_ probability: Int) -> UIColor {
        if probability >= 75 {
            return .systemGreen
        } else if probability >= 50 {
            return .systemYellow
        } else if probability >= 25 {
            return .systemOrange
        } else {
            return .systemRed
        }
    }

    private func attributedSightabilityText(probability: Int, font: UIFont) -> NSAttributedString {
        let color = colorForSightability(probability)
        let fontSize = font.pointSize
        let config = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .bold)
        let boldFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        
        let attributedString = NSMutableAttributedString()
        if let icon = UIImage(systemName: "binoculars.fill", withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal) {
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - icon.size.height) / 2, width: icon.size.width, height: icon.size.height)
            attributedString.append(NSAttributedString(attachment: attachment))
        }
        attributedString.append(NSAttributedString(string: " Sightability - ", attributes: [.font: font, .foregroundColor: UIColor.label]))
        attributedString.append(NSAttributedString(string: "\(probability)%", attributes: [.font: boldFont, .foregroundColor: color]))
        
        return attributedString
    }

    private func applyBadgeIconStyle() {
        if let compactIcon = compactBadgeIconImageView {
            styleBadgeIconContainer(compactIcon, color: currentStatusColor)
            updateBadgeIcon(compactIcon, color: currentStatusColor)
        }

        if let wideIcon = wideBadgeIconImageView {
            styleBadgeIconContainer(wideIcon, color: currentStatusColor)
            updateBadgeIcon(wideIcon, color: currentStatusColor)
        }
        
        // Style new premium UI elements
        calendarContainer.backgroundColor = currentStatusColor.withAlphaComponent(0.1)
        calendarIcon.tintColor = currentStatusColor
        
        compactCalendarIcon.tintColor = currentStatusColor
        
        sightabilityStatusLabel.textColor = currentStatusColor
    }

    private func updateBadgeIcon(_ imageView: UIImageView, color: UIColor) {
        let baseSize = max(12, min(imageView.bounds.width, imageView.bounds.height) * 0.9)
        let symbolPointSize = max(baseSize, compactBadgeTitleLabel.font.pointSize)
        let iconConfig = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        imageView.image = UIImage(systemName: "bird.circle.fill", withConfiguration: iconConfig)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        imageView.tintColor = color
    }
}
