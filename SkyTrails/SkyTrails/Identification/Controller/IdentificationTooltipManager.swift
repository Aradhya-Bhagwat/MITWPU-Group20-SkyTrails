import UIKit

// MARK: - AttachedTooltipView

class AttachedTooltipView: UIView {
    private let label = UILabel()
    private let arrowSize: CGSize = CGSize(width: 16, height: 8)
    private(set) var arrowPosition: CGFloat = 0.5
    private(set) var isArrowUp: Bool = true

    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    init(text: String) {
        super.init(frame: .zero)
        backgroundColor = .clear

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

    required init?(coder: NSCoder) { fatalError() }

    func setupArrow(isUp: Bool, relativePosition: CGFloat) {
        self.isArrowUp = isUp
        self.arrowPosition = relativePosition

        topConstraint?.isActive = false
        bottomConstraint?.isActive = false

        if isUp {
            topConstraint = label.topAnchor.constraint(equalTo: topAnchor, constant: arrowSize.height + 8)
            bottomConstraint = label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        } else {
            topConstraint = label.topAnchor.constraint(equalTo: topAnchor, constant: 8)
            bottomConstraint = label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(arrowSize.height + 8))
        }
        topConstraint?.isActive = true
        bottomConstraint?.isActive = true
        setNeedsDisplay()
    }

    func updateText(_ text: String) {
        label.text = text
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let cornerRadius: CGFloat = 8
        let arrowW = arrowSize.width
        let arrowH = arrowSize.height

        let bubbleRect = CGRect(
            x: 0, y: isArrowUp ? arrowH : 0,
            width: rect.width, height: rect.height - arrowH
        )
        let arrowX = max(cornerRadius + arrowW / 2, min(rect.width - cornerRadius - arrowW / 2, rect.width * arrowPosition))

        let path = UIBezierPath()
        path.append(UIBezierPath(roundedRect: bubbleRect, cornerRadius: cornerRadius))

        let arrowPath = UIBezierPath()
        if isArrowUp {
            arrowPath.move(to: CGPoint(x: arrowX - arrowW / 2, y: arrowH))
            arrowPath.addLine(to: CGPoint(x: arrowX, y: 0))
            arrowPath.addLine(to: CGPoint(x: arrowX + arrowW / 2, y: arrowH))
        } else {
            arrowPath.move(to: CGPoint(x: arrowX - arrowW / 2, y: rect.height - arrowH))
            arrowPath.addLine(to: CGPoint(x: arrowX, y: rect.height))
            arrowPath.addLine(to: CGPoint(x: arrowX + arrowW / 2, y: rect.height - arrowH))
        }
        arrowPath.close()
        path.append(arrowPath)

        UIColor.systemBlue.withAlphaComponent(0.95).setFill()
        path.fill()
    }
}

// MARK: - IdentificationTooltipManager

class IdentificationTooltipManager {
    static let shared = IdentificationTooltipManager()

    private var tooltipView: AttachedTooltipView?
    private var timer: Timer?

    // Step-by-step state
    private var steps: [(message: String, targetProvider: () -> UIView?)] = []
    private var currentStepIndex: Int = 0
    private weak var parentView: UIView?

    // Prevents multiple rapid calls from advancing more than one step
    private var isAdvancingStep: Bool = false

    // Leading/top constraints for repositioning
    private var leadingConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?

    private init() {}

    // MARK: - Public API

    /// Single attached tooltip (one step)
    func scheduleAttachedTooltip(in parentView: UIView, message: String, targetProvider: @escaping () -> UIView?) {
        scheduleStepByStepTooltips(in: parentView, steps: [(message: message, targetProvider: targetProvider)])
    }

    /// Multi-step attached tooltips — advances on tap
    func scheduleStepByStepTooltips(in parentView: UIView, steps: [(message: String, targetProvider: () -> UIView?)]) {
        cancelTooltip()
        guard !steps.isEmpty else { return }

        self.steps = steps
        self.currentStepIndex = 0
        self.parentView = parentView

        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.showCurrentStep()
        }
    }

    /// Legacy floating tooltip (kept for compatibility)
    func scheduleTooltip(in view: UIView, message: String, bottomOffset: CGFloat = -100) {
        cancelTooltip()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.showFloatingTooltip(in: view, message: message, bottomOffset: bottomOffset)
        }
    }

    func cancelTooltip() {
        timer?.invalidate()
        timer = nil
        steps = []
        currentStepIndex = 0
        isAdvancingStep = false
        hideTooltip()
    }

    /// Call when the user completes the current step's action.
    /// Hides the current tooltip and waits 5 seconds before showing the next one.
    /// Repeated calls within the same step (e.g. every keystroke) are ignored.
    func advanceToNextStep() {
        // Guard: only advance once per step — ignore repeated calls (e.g. textViewDidChange firing on every keystroke)
        guard !isAdvancingStep else { return }
        isAdvancingStep = true

        currentStepIndex += 1

        // Hide whatever is currently showing and cancel any pending timer
        timer?.invalidate()
        timer = nil
        hideTooltip()

        guard currentStepIndex < steps.count, parentView != nil else {
            // All steps done — clean up
            steps = []
            currentStepIndex = 0
            isAdvancingStep = false
            return
        }

        // Schedule the next tooltip after a fresh 5-second pause
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.isAdvancingStep = false
            self?.showCurrentStep()
        }
    }


    // MARK: - Step Logic

    private func showCurrentStep() {
        guard currentStepIndex < steps.count, let parentView = parentView else {
            hideTooltip()
            return
        }

        let step = steps[currentStepIndex]
        guard let targetView = step.targetProvider() else {
            // Skip steps whose target is nil
            currentStepIndex += 1
            showCurrentStep()
            return
        }

        if let existing = tooltipView {
            // Animate reposition to new target
            animateReposition(existing, to: targetView, in: parentView, message: step.message)
        } else {
            showAttachedTooltip(to: targetView, in: parentView, message: step.message)
        }
    }

    @objc private func handleTap() {
        // Tapping the bubble also hides it and waits 5 seconds before showing the next step
        advanceToNextStep()
    }

    // MARK: - Tooltip Presentation

    private func showAttachedTooltip(to targetView: UIView, in parentView: UIView, message: String) {
        guard tooltipView == nil else { return }

        let tooltip = AttachedTooltipView(text: message)
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        tooltip.alpha = 0
        parentView.addSubview(tooltip)

        let padding: CGFloat = 16
        let maxWidth = parentView.bounds.width - padding * 2
        tooltip.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth).isActive = true

        let (tooltipX, tooltipY, isArrowUp, relativeArrowX) = calculatePosition(
            for: targetView, in: parentView, maxWidth: maxWidth, tooltip: tooltip
        )

        tooltip.setupArrow(isUp: isArrowUp, relativePosition: relativeArrowX)

        let leading = tooltip.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: tooltipX)
        let top = tooltip.topAnchor.constraint(equalTo: parentView.topAnchor, constant: tooltipY)
        leading.isActive = true
        top.isActive = true

        self.leadingConstraint = leading
        self.topConstraint = top

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tooltip.addGestureRecognizer(tap)
        tooltip.isUserInteractionEnabled = true

        self.tooltipView = tooltip

        UIView.animate(withDuration: 0.3) { tooltip.alpha = 1 }
    }

    private func animateReposition(_ tooltip: AttachedTooltipView, to targetView: UIView, in parentView: UIView, message: String) {
        let padding: CGFloat = 16
        let maxWidth = parentView.bounds.width - padding * 2

        let (tooltipX, tooltipY, isArrowUp, relativeArrowX) = calculatePosition(
            for: targetView, in: parentView, maxWidth: maxWidth, tooltip: tooltip
        )

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            tooltip.updateText(message)
            tooltip.setupArrow(isUp: isArrowUp, relativePosition: relativeArrowX)
            self.leadingConstraint?.constant = tooltipX
            self.topConstraint?.constant = tooltipY
            parentView.layoutIfNeeded()
        }
    }

    private func calculatePosition(for targetView: UIView, in parentView: UIView, maxWidth: CGFloat, tooltip: AttachedTooltipView) -> (x: CGFloat, y: CGFloat, isArrowUp: Bool, relativeArrowX: CGFloat) {
        let padding: CGFloat = 16
        let targetRect = targetView.convert(targetView.bounds, to: parentView)

        // Estimate tooltip size
        let estimatedSize = tooltip.systemLayoutSizeFitting(
            CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        let spaceBelow = parentView.bounds.height - targetRect.maxY
        let spaceAbove = targetRect.minY
        let isArrowUp = spaceBelow >= spaceAbove

        var tooltipX = targetRect.midX - estimatedSize.width / 2
        tooltipX = max(padding, min(tooltipX, parentView.bounds.width - padding - estimatedSize.width))

        var tooltipY = isArrowUp ? targetRect.maxY + 8 : targetRect.minY - estimatedSize.height - 8

        // Clamp to safe area
        let safeTop = parentView.safeAreaInsets.top + 8
        let safeBottom = parentView.bounds.height - parentView.safeAreaInsets.bottom - 8
        if tooltipY < safeTop { tooltipY = safeTop }
        if tooltipY + estimatedSize.height > safeBottom { tooltipY = safeBottom - estimatedSize.height }

        let relativeArrowX = max(0.1, min(0.9, (targetRect.midX - tooltipX) / estimatedSize.width))

        return (tooltipX, tooltipY, isArrowUp, relativeArrowX)
    }

    private func showFloatingTooltip(in parentView: UIView, message: String, bottomOffset: CGFloat) {
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

        UIView.animate(withDuration: 0.3) { container.alpha = 1 }
    }

    private func hideTooltip() {
        guard let view = tooltipView else { return }
        tooltipView = nil
        leadingConstraint = nil
        topConstraint = nil
        UIView.animate(withDuration: 0.3, animations: { view.alpha = 0 }) { _ in
            view.removeFromSuperview()
        }
    }
}
