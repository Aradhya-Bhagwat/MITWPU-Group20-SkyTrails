//
//  sightablityGraph.swift
//  SkyTrails
//
//  Created by SDC-USER on 20/02/26.
//

import UIKit

final class SightabilityGraphView: UIView {
    private let yAxisLayer = CAShapeLayer()
    private let xAxisLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()
    private let areaLayer = CAShapeLayer()
    private let lineLayer = CAShapeLayer()
    private var values: [Int] = []
    private var labelLayers: [CATextLayer] = []
    private let monthLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        gridLayer.strokeColor = UIColor.systemGray4.withAlphaComponent(0.7).cgColor
        gridLayer.lineWidth = 0.8
        gridLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(gridLayer)

        yAxisLayer.strokeColor = UIColor.systemGray2.cgColor
        yAxisLayer.lineWidth = 1.1
        yAxisLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(yAxisLayer)

        xAxisLayer.strokeColor = UIColor.systemGray2.cgColor
        xAxisLayer.lineWidth = 1.1
        xAxisLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(xAxisLayer)

        areaLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.14).cgColor
        areaLayer.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(areaLayer)

        lineLayer.strokeColor = UIColor.systemBlue.cgColor
        lineLayer.lineWidth = 2
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round
        layer.addSublayer(lineLayer)
    }

    func setProbabilities(_ probabilities: [Int]) {
        values = probabilities.map { min(100, max(0, $0)) }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawGraph()
    }

    private func drawGraph() {
        let plotInsets = UIEdgeInsets(top: 10, left: 44, bottom: 22, right: 6)
        let rect = bounds.inset(by: plotInsets)
        guard rect.width > 30, rect.height > 30 else {
            clearLayers()
            return
        }

        clearTextLayers()

        // Draw axes
        let yAxisPath = UIBezierPath()
        yAxisPath.move(to: CGPoint(x: rect.minX, y: rect.minY))
        yAxisPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        yAxisLayer.path = yAxisPath.cgPath

        let xAxisPath = UIBezierPath()
        xAxisPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        xAxisPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        xAxisLayer.path = xAxisPath.cgPath

        // Draw Y grid + labels to represent 1-100%
        let yTicks = [1, 25, 50, 75, 100]
        let gridPath = UIBezierPath()
        for tick in yTicks {
            let normalized = CGFloat(tick - 1) / 99.0
            let y = rect.maxY - normalized * rect.height
            gridPath.move(to: CGPoint(x: rect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: rect.maxX, y: y))
            addTextLayer(
                text: "\(tick)",
                frame: CGRect(x: 0, y: y - 7, width: rect.minX - 4, height: 12),
                alignment: .right
            )
        }
        gridLayer.path = gridPath.cgPath

        // Draw X month labels Jan to Dec
        let monthStep = rect.width / 11.0
        for (index, month) in monthLabels.enumerated() {
            let x = rect.minX + CGFloat(index) * monthStep
            let labelWidth: CGFloat = 22
            addTextLayer(
                text: month,
                frame: CGRect(x: x - labelWidth / 2, y: rect.maxY + 4, width: labelWidth, height: 12),
                alignment: .center
            )
        }

        // Y axis title
        addVerticalTextLayer(
            text: "Percentage of\nabundance",
            center: CGPoint(x: 16, y: rect.midY),
            fontSize: 12
        )

        let series: [Int] = values.isEmpty ? Array(repeating: 1, count: 12) : values
        let normalizedSeries: [Int]
        if series.count == 12 {
            normalizedSeries = series
        } else if series.count > 12 {
            normalizedSeries = Array(series.prefix(12))
        } else {
            normalizedSeries = series + Array(repeating: series.last ?? 1, count: 12 - series.count)
        }

        let stepX = rect.width / CGFloat(max(1, normalizedSeries.count - 1))
        let linePath = UIBezierPath()
        for (i, v) in normalizedSeries.enumerated() {
            let x = rect.minX + CGFloat(i) * stepX
            let normalized = CGFloat(v - 1) / 99.0
            let y = rect.maxY - normalized * rect.height
            let point = CGPoint(x: x, y: y)
            if i == 0 {
                linePath.move(to: point)
            } else {
                linePath.addLine(to: point)
            }
        }
        lineLayer.path = linePath.cgPath

        let areaPath = UIBezierPath(cgPath: linePath.cgPath)
        areaPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        areaPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        areaPath.close()
        areaLayer.path = areaPath.cgPath
    }

    private func clearLayers() {
        yAxisLayer.path = nil
        xAxisLayer.path = nil
        gridLayer.path = nil
        areaLayer.path = nil
        lineLayer.path = nil
        clearTextLayers()
    }

    private func clearTextLayers() {
        labelLayers.forEach { $0.removeFromSuperlayer() }
        labelLayers.removeAll()
    }

    private func addTextLayer(
        text: String,
        frame: CGRect,
        alignment: CATextLayerAlignmentMode,
        fontSize: CGFloat = 8
    ) {
        let textLayer = CATextLayer()
        textLayer.frame = frame.integral
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.alignmentMode = alignment
        textLayer.foregroundColor = UIColor.secondaryLabel.cgColor
        textLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(textLayer)
        labelLayers.append(textLayer)
    }

    private func addVerticalTextLayer(
        text: String,
        center: CGPoint,
        fontSize: CGFloat = 8
    ) {
        let textLayer = CATextLayer()
        textLayer.frame = CGRect(x: center.x - 70, y: center.y - 14, width: 140, height: 28)
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.isWrapped = true
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = UIColor.secondaryLabel.cgColor
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 2))
        layer.addSublayer(textLayer)
        labelLayers.append(textLayer)
    }
}
