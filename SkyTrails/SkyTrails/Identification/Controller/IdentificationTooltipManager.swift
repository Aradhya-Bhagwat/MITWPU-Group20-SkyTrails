import UIKit

class AttachedTooltipView: UIView {
    private let label = UILabel()
    private let arrowSize: CGSize = CGSize(width: 16, height: 8)
    private var arrowPosition: CGFloat = 0.5
    private var isArrowUp: Bool = true
    
    init(text: String) {
        super.init(frame: .zero)
        self.backgroundColor = .clear
        
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupArrow(isUp: Bool, relativePosition: CGFloat) {
        self.isArrowUp = isUp
        self.arrowPosition = relativePosition
        
        if isUp {
            label.topAnchor.constraint(equalTo: topAnchor, constant: arrowSize.height + 8).isActive = true
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true
        } else {
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(arrowSize.height + 8)).isActive = true
        }
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        let cornerRadius: CGFloat = 8
        let arrowW = arrowSize.width
        let arrowH = arrowSize.height
        
        let bubbleRect = CGRect(
            x: 0,
            y: isArrowUp ? arrowH : 0,
            width: rect.width,
            height: rect.height - arrowH
        )
        
        let arrowX = max(cornerRadius + arrowW/2, min(rect.width - cornerRadius - arrowW/2, rect.width * arrowPosition))
        
        let bubblePath = UIBezierPath(roundedRect: bubbleRect, cornerRadius: cornerRadius)
        path.append(bubblePath)
        
        let arrowPath = UIBezierPath()
        if isArrowUp {
            arrowPath.move(to: CGPoint(x: arrowX - arrowW/2, y: arrowH))
            arrowPath.addLine(to: CGPoint(x: arrowX, y: 0))
            arrowPath.addLine(to: CGPoint(x: arrowX + arrowW/2, y: arrowH))
            arrowPath.close()
        } else {
            arrowPath.move(to: CGPoint(x: arrowX - arrowW/2, y: rect.height - arrowH))
            arrowPath.addLine(to: CGPoint(x: arrowX, y: rect.height))
            arrowPath.addLine(to: CGPoint(x: arrowX + arrowW/2, y: rect.height - arrowH))
            arrowPath.close()
        }
        path.append(arrowPath)
        
        UIColor.systemBlue.withAlphaComponent(0.95).setFill()
        path.fill()
    }
}

class IdentificationTooltipManager {
    static let shared = IdentificationTooltipManager()
    
    private var tooltipView: UIView?
    private var timer: Timer?
    
    private init() {}
    
    // For simple floating tooltips
    func scheduleTooltip(in view: UIView, message: String, bottomOffset: CGFloat = -100) {
        cancelTooltip()
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.showTooltip(in: view, message: message, bottomOffset: bottomOffset)
        }
    }
    
    // For attached tooltips pointing to a specific view
    func scheduleAttachedTooltip(in parentView: UIView, message: String, targetProvider: @escaping () -> UIView?) {
        cancelTooltip()
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let targetView = targetProvider() else { return }
            self?.showAttachedTooltip(to: targetView, in: parentView, message: message)
        }
    }
    
    func cancelTooltip() {
        timer?.invalidate()
        timer = nil
        hideTooltip()
    }
    
    private func showAttachedTooltip(to targetView: UIView, in parentView: UIView, message: String) {
        guard tooltipView == nil else { return }
        
        let targetRect = targetView.convert(targetView.bounds, to: parentView)
        
        let tooltip = AttachedTooltipView(text: message)
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        tooltip.alpha = 0
        parentView.addSubview(tooltip)
        
        // Calculate position
        let padding: CGFloat = 16
        let tooltipMaxWidth = parentView.bounds.width - padding * 2
        
        tooltip.widthAnchor.constraint(lessThanOrEqualToConstant: tooltipMaxWidth).isActive = true
        
        // Add temporary constraints to layout and get size
        let tempX = tooltip.centerXAnchor.constraint(equalTo: parentView.centerXAnchor)
        let tempY = tooltip.centerYAnchor.constraint(equalTo: parentView.centerYAnchor)
        tempX.isActive = true
        tempY.isActive = true
        parentView.layoutIfNeeded()
        
        let tooltipSize = tooltip.systemLayoutSizeFitting(
            CGSize(width: tooltipMaxWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        tempX.isActive = false
        tempY.isActive = false
        
        let spaceAbove = targetRect.minY
        let spaceBelow = parentView.bounds.height - targetRect.maxY
        
        let isArrowUp = spaceBelow >= spaceAbove
        
        // Setup arrow and get final size
        tooltip.setupArrow(isUp: isArrowUp, relativePosition: 0.5) // Will adjust relative position below
        parentView.layoutIfNeeded()
        
        let finalSize = tooltip.systemLayoutSizeFitting(
            CGSize(width: tooltipMaxWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        var tooltipX = targetRect.midX - finalSize.width / 2
        
        // Bound X to screen
        if tooltipX < padding {
            tooltipX = padding
        } else if tooltipX + finalSize.width > parentView.bounds.width - padding {
            tooltipX = parentView.bounds.width - padding - finalSize.width
        }
        
        let relativeArrowX = (targetRect.midX - tooltipX) / finalSize.width
        let clampedRelativeArrowX = max(0.1, min(0.9, relativeArrowX))
        tooltip.setupArrow(isUp: isArrowUp, relativePosition: clampedRelativeArrowX)
        
        var tooltipY = isArrowUp ? targetRect.maxY + 8 : targetRect.minY - finalSize.height - 8
        
        let safeTop = parentView.safeAreaInsets.top + 8
        let safeBottom = parentView.bounds.height - parentView.safeAreaInsets.bottom - 8
        
        if tooltipY < safeTop {
            tooltipY = safeTop
        } else if tooltipY + finalSize.height > safeBottom {
            tooltipY = safeBottom - finalSize.height
        }
        
        NSLayoutConstraint.activate([
            tooltip.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: tooltipX),
            tooltip.topAnchor.constraint(equalTo: parentView.topAnchor, constant: tooltipY)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tooltip.addGestureRecognizer(tap)
        tooltip.isUserInteractionEnabled = true
        
        self.tooltipView = tooltip
        
        UIView.animate(withDuration: 0.3) {
            tooltip.alpha = 1
        }
    }
    
    private func showTooltip(in parentView: UIView, message: String, bottomOffset: CGFloat) {
        guard tooltipView == nil else { return }
        
        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.95)
        container.layer.cornerRadius = 12
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.2
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        container.layer.shadowRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alpha = 0
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        parentView.addSubview(container)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            container.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: parentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(lessThanOrEqualTo: parentView.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.bottomAnchor, constant: bottomOffset)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        
        self.tooltipView = container
        
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1
        }
    }
    
    @objc private func handleTap() {
        cancelTooltip()
    }
    
    private func hideTooltip() {
        guard let view = tooltipView else { return }
        self.tooltipView = nil
        UIView.animate(withDuration: 0.3, animations: {
            view.alpha = 0
        }) { _ in
            view.removeFromSuperview()
        }
    }
}
