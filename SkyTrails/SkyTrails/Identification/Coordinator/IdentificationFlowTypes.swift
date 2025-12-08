//
//  IdentificationFlowTypes.swift
//  SkyTrails
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

enum IdentificationStep{
    case size
    case fieldMarks
    case shape
    case dateLocation
}

protocol IdentificationFlowStepDelegate: AnyObject {
    func didFinishStep()
}
protocol IdentificationProgressUpdatable: AnyObject {
    func updateProgress(current: Int, total: Int)
}

