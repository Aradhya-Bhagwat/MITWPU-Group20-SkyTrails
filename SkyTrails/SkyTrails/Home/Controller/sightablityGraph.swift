//
//  sightablityGraph.swift
//  SkyTrails
//
//  Created by SDC-USER on 20/02/26.
//

import UIKit

final class SightabilityGraphView: UIView {
    private let areaLayer = CAShapeLayer()
    private let lineLayer = CAShapeLayer()
    private let baselineLayer = CAShapeLayer()
    private var values: [Int] = []

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

        baselineLayer.strokeColor = UIColor.systemGray4.cgColor
        baselineLayer.lineWidth = 1
        baselineLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(baselineLayer)

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
        let rect = bounds.insetBy(dx: 2, dy: 2)
        guard rect.width > 4, rect.height > 4 else {
            baselineLayer.path = nil
            areaLayer.path = nil
            lineLayer.path = nil
            return
        }

        let baselinePath = UIBezierPath()
        baselinePath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        baselinePath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        baselineLayer.path = baselinePath.cgPath

        let series: [Int]
        if values.isEmpty {
            series = [0, 0]
        } else {
            series = values
        }

        let maxV = max(100, series.max() ?? 100)
        let minV = min(0, series.min() ?? 0)
        let range = max(1, maxV - minV)
        let stepX = rect.width / CGFloat(max(1, series.count - 1))

        let linePath = UIBezierPath()
        for (i, v) in series.enumerated() {
            let x = rect.minX + CGFloat(i) * stepX
            let normalized = CGFloat(v - minV) / CGFloat(range)
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
}
