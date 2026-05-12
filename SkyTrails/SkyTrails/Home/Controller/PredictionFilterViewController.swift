import UIKit

class PredictionFilterViewController: UIViewController {
    weak var delegate: PredictionFilterDelegate?
    
    var currentSort: PredictionSortOption = .sightabilityDesc
    var minRange: Float = 1
    var maxRange: Float = 99
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Filter & Sort"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let sortLabel: UILabel = {
        let label = UILabel()
        label.text = "Sort By"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var sortButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(currentSort.rawValue, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.contentHorizontalAlignment = .left
        btn.backgroundColor = .secondarySystemBackground
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.showsMenuAsPrimaryAction = true
        return btn
    }()
    
    private let rangeLabel: UILabel = {
        let label = UILabel()
        label.text = "Sightability Range"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let rangeValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let rangeSlider: RangeSlider = {
        let slider = RangeSlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private let applyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Apply Filters", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupMenu()
        
        rangeSlider.lowerValue = Double(minRange)
        rangeSlider.upperValue = Double(maxRange)
        updateRangeLabel()
        
        rangeSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        applyButton.addTarget(self, action: #selector(didTapApply), for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure the slider is rendered correctly after layout
        rangeSlider.setNeedsLayout()
        rangeSlider.layoutIfNeeded()
    }
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(sortLabel)
        view.addSubview(sortButton)
        view.addSubview(rangeLabel)
        view.addSubview(rangeValueLabel)
        view.addSubview(rangeSlider)
        view.addSubview(applyButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            sortLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            sortLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            sortButton.topAnchor.constraint(equalTo: sortLabel.bottomAnchor, constant: 8),
            sortButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sortButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sortButton.heightAnchor.constraint(equalToConstant: 44),
            
            rangeLabel.topAnchor.constraint(equalTo: sortButton.bottomAnchor, constant: 32),
            rangeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            rangeValueLabel.centerYAnchor.constraint(equalTo: rangeLabel.centerYAnchor),
            rangeValueLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            rangeSlider.topAnchor.constraint(equalTo: rangeLabel.bottomAnchor, constant: 24),
            rangeSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            rangeSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            rangeSlider.heightAnchor.constraint(equalToConstant: 32),
            
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            applyButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupMenu() {
        let actions = PredictionSortOption.allCases.map { option in
            UIAction(title: option.rawValue, state: option == currentSort ? .on : .off) { [weak self] _ in
                self?.currentSort = option
                self?.sortButton.setTitle(option.rawValue, for: .normal)
                self?.setupMenu() // Refresh checkmarks
            }
        }
        sortButton.menu = UIMenu(title: "Sort Order", children: actions)
    }
    
    @objc private func sliderValueChanged(_ sender: RangeSlider) {
        updateRangeLabel()
    }
    
    private func updateRangeLabel() {
        rangeValueLabel.text = "\(Int(rangeSlider.lowerValue))% - \(Int(rangeSlider.upperValue))%"
    }
    
    @objc private func didTapApply() {
        delegate?.didApplyFilters(
            sort: currentSort,
            minRange: Int(rangeSlider.lowerValue),
            maxRange: Int(rangeSlider.upperValue)
        )
        dismiss(animated: true)
    }
}

// MARK: - Custom Range Slider Implementation
class RangeSlider: UIControl {
    var minimumValue: Double = 1.0 { didSet { updateLayerFrames() } }
    var maximumValue: Double = 99.0 { didSet { updateLayerFrames() } }
    var lowerValue: Double = 1.0 { didSet { updateLayerFrames() } }
    var upperValue: Double = 99.0 { didSet { updateLayerFrames() } }
    
    private let trackLayer = CALayer()
    private let rangeTrackLayer = CALayer()
    private let lowerThumbLayer = CALayer()
    private let upperThumbLayer = CALayer()
    
    private var previousLocation = CGPoint()
    private let thumbWidth: CGFloat = 28.0
    
    override var frame: CGRect {
        didSet { updateLayerFrames() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        trackLayer.backgroundColor = UIColor.systemGray5.cgColor
        layer.addSublayer(trackLayer)
        
        rangeTrackLayer.backgroundColor = UIColor.systemBlue.cgColor
        layer.addSublayer(rangeTrackLayer)
        
        setupThumb(lowerThumbLayer)
        setupThumb(upperThumbLayer)
        
        updateLayerFrames()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupThumb(_ thumb: CALayer) {
        thumb.backgroundColor = UIColor.white.cgColor
        thumb.cornerRadius = thumbWidth / 2
        thumb.shadowColor = UIColor.black.cgColor
        thumb.shadowOpacity = 0.2
        thumb.shadowOffset = CGSize(width: 0, height: 2)
        thumb.shadowRadius = 4
        layer.addSublayer(thumb)
    }
    
    private func updateLayerFrames() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let trackHeight: CGFloat = 6.0
        trackLayer.frame = CGRect(x: 0, y: (bounds.height - trackHeight) / 2, width: bounds.width, height: trackHeight)
        trackLayer.cornerRadius = trackHeight / 2
        
        let lowerX = CGFloat(positionForValue(lowerValue))
        let upperX = CGFloat(positionForValue(upperValue))
        
        rangeTrackLayer.frame = CGRect(x: lowerX, y: (bounds.height - trackHeight) / 2, width: upperX - lowerX, height: trackHeight)
        rangeTrackLayer.cornerRadius = trackHeight / 2
        
        lowerThumbLayer.frame = CGRect(x: lowerX - thumbWidth / 2, y: (bounds.height - thumbWidth) / 2, width: thumbWidth, height: thumbWidth)
        upperThumbLayer.frame = CGRect(x: upperX - thumbWidth / 2, y: (bounds.height - thumbWidth) / 2, width: thumbWidth, height: thumbWidth)
        
        CATransaction.commit()
    }
    
    private func positionForValue(_ value: Double) -> Double {
        return Double(bounds.width - thumbWidth) * (value - minimumValue) / (maximumValue - minimumValue) + Double(thumbWidth / 2)
    }
    
    private func valueForPosition(_ position: Double) -> Double {
        return Double(minimumValue) + (position - Double(thumbWidth / 2)) * (maximumValue - minimumValue) / Double(bounds.width - thumbWidth)
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        previousLocation = touch.location(in: self)
        
        if lowerThumbLayer.frame.contains(previousLocation) {
            lowerThumbLayer.zPosition = 1
            upperThumbLayer.zPosition = 0
            return true
        } else if upperThumbLayer.frame.contains(previousLocation) {
            upperThumbLayer.zPosition = 1
            lowerThumbLayer.zPosition = 0
            return true
        }
        return false
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        let deltaLocation = Double(location.x - previousLocation.x)
        let deltaValue = (maximumValue - minimumValue) * deltaLocation / Double(bounds.width - thumbWidth)
        
        previousLocation = location
        
        if lowerThumbLayer.zPosition == 1 {
            lowerValue = max(minimumValue, min(lowerValue + deltaValue, upperValue - 5))
        } else {
            upperValue = min(maximumValue, max(upperValue + deltaValue, lowerValue + 5))
        }
        
        sendActions(for: .valueChanged)
        return true
    }
}
