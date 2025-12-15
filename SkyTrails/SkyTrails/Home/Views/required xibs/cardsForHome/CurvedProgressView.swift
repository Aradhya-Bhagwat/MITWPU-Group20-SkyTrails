import UIKit

class CurvedProgressView: UIView {
    
    // MARK: - Layer Properties
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    
    // Concentric Circle Layers (End Caps)
    private let startOuterCircleLayer = CAShapeLayer()
    private let startInnerCircleLayer = CAShapeLayer()
    private let endOuterCircleLayer = CAShapeLayer()
    private let endInnerCircleLayer = CAShapeLayer()
    
    // Define the colors
    private let progressColor = UIColor.systemBlue.cgColor
    private let trackColor = UIColor.systemBlue.withAlphaComponent(0.35).cgColor
    private let innerCircleColor = UIColor.white.cgColor
    
    // Define sizes
    private let lineWidth: CGFloat = 7.0
    private let outerCircleRadius: CGFloat = 10.0
    private let innerCircleRadius: CGFloat = 3.0
    
    var progress: Float = 0.0 {
        didSet {
            animateProgress(to: progress)
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    // MARK: - Setup (Mostly unchanged, just added layers)
    private func setupLayers() {
        self.backgroundColor = UIColor.clear
        
        // 1. Configure Line Layers
        [trackLayer, progressLayer].forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = lineWidth
            layer.lineCap = .round
        }
        
        // 2. Configure Circle Layers (Circles are filled, not stroked)
        // Ensure layers are added in the correct order for visual hierarchy:
        self.layer.addSublayer(trackLayer)
        self.layer.addSublayer(progressLayer)
        
        self.layer.addSublayer(startOuterCircleLayer)
        self.layer.addSublayer(endOuterCircleLayer)
        self.layer.addSublayer(startInnerCircleLayer)
        self.layer.addSublayer(endInnerCircleLayer)
        
        // Apply colors after layers are added
        trackLayer.strokeColor = trackColor
        progressLayer.strokeColor = progressColor
        progressLayer.strokeEnd = 0.0
    }
    
    // MARK: - Drawing the Curve (***MAIN CHANGE HERE***)
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 1. Define the quadratic Bezier curve path
        let path = UIBezierPath()
        
        // *** CHANGE 1: CALCULATE VERTICAL OFFSET***
        // Ensures the line and circles are fully visible within the view's bottom edge.
        let verticalOffset = outerCircleRadius + (lineWidth / 2)

        // Start point is at the bottom left, offset inwards by the radius
        path.move(to: CGPoint(x: outerCircleRadius, y: bounds.height - verticalOffset))
        
        // Define the end point (right edge, offset inwards)
        let endX = bounds.width - outerCircleRadius
        let endY = bounds.height - verticalOffset
        
        // Define the control point (center top of the view)
//        let controlPointY: CGFloat = 0
        
        // *** CHANGE 2: USE QUADRATIC CURVE (Reverts from addLine)***
        path.addQuadCurve(to: CGPoint(x: endX, y: endY),
                          controlPoint: CGPoint(x: bounds.width / 2  , y: bounds.height / 1.6 ))
        
        let cgPath = path.cgPath
        
        // Assign the full path to both line layers
        trackLayer.path = cgPath
        progressLayer.path = cgPath
        
        // 2. CALCULATE AND DRAW CONCENTRIC CIRCLES
        
        // The center of the circles must align with the start and end points of the line.
        let startCircleCenter = CGPoint(x: outerCircleRadius, y: bounds.height - verticalOffset)
        let endCircleCenter = CGPoint(x: endX, y: endY)
        
        // --- START POINT CIRCLES (Dark Blue, White) ---
        drawCircle(layer: startOuterCircleLayer, center: startCircleCenter, radius: outerCircleRadius, color: progressColor)
        drawCircle(layer: startInnerCircleLayer, center: startCircleCenter, radius: innerCircleRadius, color: innerCircleColor)
        
        // --- END POINT CIRCLES (Pale Blue, White) ---
        drawCircle(layer: endOuterCircleLayer, center: endCircleCenter, radius: outerCircleRadius, color: trackColor)
        drawCircle(layer: endInnerCircleLayer, center: endCircleCenter, radius: innerCircleRadius, color: innerCircleColor)
        
        // 3. Reset progress display
        progressLayer.strokeEnd = CGFloat(progress)
        
        // Ensure layers resize and reposition correctly
        trackLayer.frame = bounds
        progressLayer.frame = bounds
    }
    
    // MARK: - Helper Function to Draw a Filled Circle (Unchanged)
    private func drawCircle(layer: CAShapeLayer, center: CGPoint, radius: CGFloat, color: CGColor) {
        // ... (function body remains the same) ...
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

    // MARK: - Animation (Unchanged)
    private func animateProgress(to value: Float) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = value
        animation.duration = 1.0
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        progressLayer.add(animation, forKey: "progressAnimation")
    }
}
