
import UIKit

class CircularSightabilityView: UIView {
    var probability: Int = 0 {
        didSet {
            label.text = "\(probability)%"
            setNeedsLayout()
            animateStroke()
        }
    }
    
    private let shapeLayer = CAShapeLayer()
    private let trackLayer = CAShapeLayer()
    
    private let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 9, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        return l
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemGray5.cgColor
        trackLayer.lineWidth = 3
        layer.addSublayer(trackLayer)
        
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.systemGreen.cgColor
        shapeLayer.lineWidth = 3
        shapeLayer.lineCap = .round
        shapeLayer.strokeEnd = 0
        layer.addSublayer(shapeLayer)
        
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 2
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: 3 * .pi / 2, clockwise: true)
        
        trackLayer.path = path.cgPath
        shapeLayer.path = path.cgPath
    }
    
    private func animateStroke() {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = CGFloat(probability) / 100.0
        animation.duration = 0.5
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        shapeLayer.add(animation, forKey: "stroke")
    }
    
    func setStrokeColor(_ color: UIColor) {
        shapeLayer.strokeColor = color.cgColor
    }
}
