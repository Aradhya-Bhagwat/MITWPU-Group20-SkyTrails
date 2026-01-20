import UIKit

class CurvedProgressView: UIView {
    
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let startOuterCircleLayer = CAShapeLayer()
    private let startInnerCircleLayer = CAShapeLayer()
    private let endOuterCircleLayer = CAShapeLayer()
    private let endInnerCircleLayer = CAShapeLayer()
    
    private let progressColor = UIColor.systemBlue.cgColor
    private let trackColor = UIColor.systemBlue.withAlphaComponent(0.35).cgColor
    private let innerCircleColor = UIColor.white.cgColor
    
    // 💡 These are now dynamic properties
    private var dynamicLineWidth: CGFloat = 7.0
    private var dynamicOuterRadius: CGFloat = 10.0
    private var dynamicInnerRadius: CGFloat = 3.0
    
    var progress: Float = 0.0 {
        didSet {
            animateProgress(to: progress)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        self.backgroundColor = UIColor.clear

        [trackLayer, progressLayer].forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
        }

        self.layer.addSublayer(trackLayer)
        self.layer.addSublayer(progressLayer)
        self.layer.addSublayer(startOuterCircleLayer)
        self.layer.addSublayer(endOuterCircleLayer)
        self.layer.addSublayer(startInnerCircleLayer)
        self.layer.addSublayer(endInnerCircleLayer)
        
        trackLayer.strokeColor = trackColor
        progressLayer.strokeColor = progressColor
        progressLayer.strokeEnd = 0.0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let currentWidth = bounds.width
        let baseWidth: CGFloat = 390.0
        
        // Calculate new sizes based on screen width
        dynamicLineWidth = (7.0 / baseWidth) * currentWidth
        dynamicOuterRadius = (10.0 / baseWidth) * currentWidth
        dynamicInnerRadius = (3.0 / baseWidth) * currentWidth
        
        // Apply the new line width to layers
        trackLayer.lineWidth = dynamicLineWidth
        progressLayer.lineWidth = dynamicLineWidth

        let path = UIBezierPath()
        let verticalOffset = dynamicOuterRadius + (dynamicLineWidth / 2)

        path.move(to: CGPoint(x: dynamicOuterRadius, y: bounds.height - verticalOffset))

        let endX = bounds.width - dynamicOuterRadius
        let endY = bounds.height - verticalOffset
        
        // Match the control point ratio as well if needed
        path.addQuadCurve(to: CGPoint(x: endX, y: endY),
                          controlPoint: CGPoint(x: bounds.width / 2, y: bounds.height / 1.6))
        
        let cgPath = path.cgPath
        trackLayer.path = cgPath
        progressLayer.path = cgPath
        
        let startCircleCenter = CGPoint(x: dynamicOuterRadius, y: bounds.height - verticalOffset)
        let endCircleCenter = CGPoint(x: endX, y: endY)
        
        drawCircle(layer: startOuterCircleLayer, center: startCircleCenter, radius: dynamicOuterRadius, color: progressColor)
        drawCircle(layer: startInnerCircleLayer, center: startCircleCenter, radius: dynamicInnerRadius, color: innerCircleColor)
        
        drawCircle(layer: endOuterCircleLayer, center: endCircleCenter, radius: dynamicOuterRadius, color: trackColor)
        drawCircle(layer: endInnerCircleLayer, center: endCircleCenter, radius: dynamicInnerRadius, color: innerCircleColor)
        
        progressLayer.strokeEnd = CGFloat(progress)
        
        trackLayer.frame = bounds
        progressLayer.frame = bounds
    }
    
    private func drawCircle(layer: CAShapeLayer, center: CGPoint, radius: CGFloat, color: CGColor) {
        let circlePath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: true
        )
        layer.path = circlePath.cgPath
        layer.fillColor = color
        layer.frame = bounds
    }

    private func animateProgress(to value: Float) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = value
        animation.duration = 1.0
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        progressLayer.add(animation, forKey: "progressAnimation")
    }
}
