//
//  IdentificationFlowTypes.swift
//  SkyTrails
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

enum IdentificationStep{
    case dateLocation
    case size
    case shape
    case fieldMarks
    case gui
    case result
}

protocol IdentificationFlowStepDelegate: AnyObject {
    func didFinishStep()
    func didTapShapes()
}
protocol IdentificationProgressUpdatable: AnyObject {
    func updateProgress(current: Int, total: Int)
}

