import UIKit

class SightabilityGraphView: UIView {
    var scores: [Int] = [] {
        didSet { setNeedsDisplay() }
    }
    var currentWeek: Int = Date().weekOfYear
    var isLoading: Bool = true {
        didSet { setNeedsDisplay() }
    }
    var lineColor: UIColor = UIColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let yAxisWidth: CGFloat = 24.0
        let bottomPadding: CGFloat = 16.0
        let graphRect = CGRect(x: yAxisWidth, y: 10, width: rect.width - yAxisWidth - 10, height: rect.height - bottomPadding - 10)
        
        let barCount = 52
        let pointWidth = graphRect.width / CGFloat(barCount - 1)
        let maxBarHeight = graphRect.height
        
        let mainColor = lineColor
        
        // Draw Y-Axis labels and grid lines
        let yAxisAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .medium),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        
        let yValues = [0, 50, 100]
        for val in yValues {
            let yStr = NSAttributedString(string: "\(val)", attributes: yAxisAttrs)
            let yPos = graphRect.maxY - (CGFloat(val) / 100.0 * maxBarHeight)
            
            let textSize = yStr.size()
            yStr.draw(at: CGPoint(x: yAxisWidth - textSize.width - 4, y: yPos - textSize.height / 2))
            
            let gridPath = UIBezierPath()
            gridPath.move(to: CGPoint(x: yAxisWidth, y: yPos))
            gridPath.addLine(to: CGPoint(x: rect.width, y: yPos))
            ctx.setStrokeColor(UIColor.separator.withAlphaComponent(0.2).cgColor)
            ctx.setLineWidth(0.5)
            ctx.setLineDash(phase: 0, lengths: [2, 2])
            ctx.addPath(gridPath.cgPath)
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: []) // reset
        
        let path = UIBezierPath()
        let fillPath = UIBezierPath()
        
        for i in 0..<barCount {
            let score = isLoading ? 30 : (i < scores.count ? scores[i] : 0)
            let barHeight = CGFloat(score) / 100.0 * maxBarHeight
            let x = graphRect.origin.x + CGFloat(i) * pointWidth
            let y = graphRect.maxY - barHeight
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
                fillPath.move(to: CGPoint(x: x, y: graphRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
            
            if i == barCount - 1 {
                fillPath.addLine(to: CGPoint(x: x, y: graphRect.maxY))
            }
        }
        
        // Gradient fill
        ctx.saveGState()
        fillPath.close()
        fillPath.addClip()
        let topColor = mainColor.withAlphaComponent(0.12).cgColor
        let bottomColor = mainColor.withAlphaComponent(0.0).cgColor
        let colors = [topColor, bottomColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: yAxisWidth, y: graphRect.minY), end: CGPoint(x: yAxisWidth, y: graphRect.maxY), options: [])
        }
        ctx.restoreGState()
        
        // Stroke
        ctx.setStrokeColor(mainColor.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(1.2)
        ctx.addPath(path.cgPath)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        
        // Draw current week indicator
        if !isLoading && currentWeek >= 1 && currentWeek <= 52 {
            let i = currentWeek - 1
            let score = i < scores.count ? scores[i] : 0
            let barHeight = CGFloat(score) / 100.0 * maxBarHeight
            let x = graphRect.origin.x + CGFloat(i) * pointWidth
            let y = graphRect.maxY - barHeight
            
            // Highlight dot
            let dotRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
            ctx.setFillColor(mainColor.cgColor)
            ctx.fillEllipse(in: dotRect)
            
            let innerDotRect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: innerDotRect)
        }
        
        // Month labels at bottom
        let months = [
            ("Jan", 0), ("Feb", 4), ("Mar", 9), ("Apr", 13),
            ("May", 17), ("Jun", 22), ("Jul", 26), ("Aug", 30),
            ("Sep", 35), ("Oct", 39), ("Nov", 43), ("Dec", 48)
        ]
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        for (label, startWeek) in months {
            let x = graphRect.origin.x + CGFloat(startWeek) * pointWidth
            let str = NSAttributedString(string: label, attributes: attrs)
            let drawX = min(x, rect.width - str.size().width)
            str.draw(at: CGPoint(x: drawX, y: rect.height - 10))
        }
    }
}
