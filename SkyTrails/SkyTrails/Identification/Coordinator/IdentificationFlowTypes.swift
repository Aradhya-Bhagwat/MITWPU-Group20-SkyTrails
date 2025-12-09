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
}

protocol IdentificationFlowStepDelegate: AnyObject {
    func didFinishStep()
}
protocol IdentificationProgressUpdatable: AnyObject {
    func updateProgress(current: Int, total: Int)
}

