import UIKit

class SightabilityGraphView: UIView {
    var scores: [Int] = [] {
        didSet { setNeedsDisplay() }
    }
    var currentWeek: Int = Date().weekOfYear
    var isLoading: Bool = true {
        didSet { setNeedsDisplay() }
    }
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let yAxisWidth: CGFloat = 36.0
        let graphRect = CGRect(x: yAxisWidth, y: 0, width: rect.width - yAxisWidth, height: rect.height)
        
        let barCount = 52
        // Prevent division by zero
        let pointWidth = barCount > 1 ? graphRect.width / CGFloat(barCount - 1) : graphRect.width
        let maxBarHeight = graphRect.height - 20 // Leave 20pts for labels
        
        // Draw Y-Axis title
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let titleStr = NSAttributedString(string: "Sightability Throughout Year", attributes: titleAttr)
        let titleSize = titleStr.size()
        
        ctx.saveGState()
        // rotate and translate to draw vertically
        ctx.translateBy(x: 6, y: maxBarHeight / 2 + titleSize.width / 2)
        ctx.rotate(by: -.pi / 2)
        titleStr.draw(at: CGPoint(x: 0, y: 0))
        ctx.restoreGState()
        
        // Draw Y-Axis labels and grid lines
        let yAxisAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        
        let yValues = [0, 25, 50, 75, 100]
        for val in yValues {
            let yStr = NSAttributedString(string: "\(val)", attributes: yAxisAttrs)
            let yPos = maxBarHeight - (CGFloat(val) / 100.0 * maxBarHeight)
            
            // Draw text right-aligned
            let textSize = yStr.size()
            let drawY = max(0, min(yPos - textSize.height / 2, maxBarHeight - textSize.height))
            yStr.draw(at: CGPoint(x: yAxisWidth - textSize.width - 4, y: drawY))
            
            // Draw grid line
            let gridPath = UIBezierPath()
            gridPath.move(to: CGPoint(x: yAxisWidth, y: yPos))
            gridPath.addLine(to: CGPoint(x: rect.width, y: yPos))
            ctx.setStrokeColor(UIColor.separator.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(0.5)
            if val == 0 {
                ctx.setLineDash(phase: 0, lengths: [])
            } else {
                ctx.setLineDash(phase: 0, lengths: [2, 2])
            }
            ctx.addPath(gridPath.cgPath)
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: []) // reset
        
        let path = UIBezierPath()
        let fillPath = UIBezierPath()
        
        for i in 0..<barCount {
            let score = isLoading ? 30 : (i < scores.count ? scores[i] : 0)
            let barHeight = CGFloat(score) / 100.0 * maxBarHeight
            let x = yAxisWidth + CGFloat(i) * pointWidth
            let y = maxBarHeight - barHeight
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
                fillPath.move(to: CGPoint(x: x, y: maxBarHeight))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
            
            if i == barCount - 1 {
                fillPath.addLine(to: CGPoint(x: x, y: maxBarHeight))
            }
        }
        
        // Gradient fill
        ctx.saveGState()
        fillPath.close()
        fillPath.addClip()
        let topColor = isLoading ? UIColor.systemGray5.withAlphaComponent(0.5).cgColor : UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        let bottomColor = isLoading ? UIColor.systemGray5.withAlphaComponent(0.1).cgColor : UIColor.systemBlue.withAlphaComponent(0.0).cgColor
        let colors = [topColor, bottomColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: yAxisWidth, y: 0), end: CGPoint(x: yAxisWidth, y: maxBarHeight), options: [])
        }
        ctx.restoreGState()
        
        // Stroke
        ctx.setStrokeColor(isLoading ? UIColor.systemGray4.cgColor : UIColor.systemBlue.cgColor)
        ctx.setLineWidth(2.0)
        ctx.addPath(path.cgPath)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        
        // Draw current week indicator
        if !isLoading && currentWeek >= 1 && currentWeek <= 52 {
            let i = currentWeek - 1
            let score = i < scores.count ? scores[i] : 0
            let barHeight = CGFloat(score) / 100.0 * maxBarHeight
            let x = yAxisWidth + CGFloat(i) * pointWidth
            let y = maxBarHeight - barHeight
            
            let dotRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
            ctx.setFillColor(UIColor.systemGreen.cgColor)
            ctx.fillEllipse(in: dotRect)
            
            // Draw a vertical line from the dot to the bottom
            let vLine = UIBezierPath()
            vLine.move(to: CGPoint(x: x, y: y + 4))
            vLine.addLine(to: CGPoint(x: x, y: maxBarHeight))
            ctx.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1.0)
            let dashPattern: [CGFloat] = [2, 2]
            ctx.setLineDash(phase: 0, lengths: dashPattern)
            ctx.addPath(vLine.cgPath)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: []) // reset
        }
        
        // Month labels at bottom
        let months = [
            ("Jan", 0), ("Feb", 4), ("Mar", 9), ("Apr", 13),
            ("May", 17), ("Jun", 22), ("Jul", 26), ("Aug", 30),
            ("Sep", 35), ("Oct", 39), ("Nov", 43), ("Dec", 48)
        ]
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.secondaryLabel
        ]
        for (label, startWeek) in months {
            let x = yAxisWidth + CGFloat(startWeek) * pointWidth
            let str = NSAttributedString(string: label, attributes: attrs)
            // Ensure label doesn't go off screen at the end
            let drawX = min(x, rect.width - str.size().width)
            str.draw(at: CGPoint(x: drawX, y: rect.height - 14))
        }
    }
}
