//
//  Coordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//


//
//  Coordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//
import UIKit
class IdentificationCoordinator{
    private let navigationController: UINavigationController
    
    private var steps: [IdentificationStep] = []
    private var currentIndex: Int = 0
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start(){
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "IdentificationViewController") as! IdentificationViewController
        vc.coordinator = self
        navigationController.setViewControllers([vc], animated: true)
        
    }
    
    func configureSteps(from options: [FieldMarkType]){
        steps.removeAll()
        for option in options where option.isSelected {
            switch option.fieldMarkName {
            case "Size":
                steps.append(.size)
            case "Field Marks":
                steps.append(.fieldMarks)
            case "Shape":
                steps.append(.shape)
            case "Location & Date":
                steps.append(.dateLocation)
            default:
                break
            }
        }
        
        currentIndex = 0
        goToNextStep()
    }
    
    func goToNextStep(){
        guard currentIndex < steps.count else {
            navigationController.popViewController(animated: true)
            return
        }
        
        let step = steps[currentIndex]
        currentIndex += 1
        
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        switch step {
            case .size:
                let vc = storyboard.instantiateViewController( withIdentifier: "IdentificationSizeViewController" ) as! IdentificationSizeViewController
                vc.delegate = self
                navigationController.pushViewController(vc, animated: true)
                
            case .fieldMarks:
                let vc = storyboard.instantiateViewController( withIdentifier: "IdentificationFieldMarksViewController" ) as! IdentificationFieldMarksViewController
                vc.delegate = self
                navigationController.pushViewController(vc, animated: true)
        case .shape:
            let vc = storyboard.instantiateViewController( withIdentifier: "IdentificationShapeViewController" ) as! IdentificationShapeViewController
            vc.delegate = self
            navigationController.pushViewController(vc, animated: true)
            
            case .dateLocation:
            let vc = storyboard.instantiateViewController( withIdentifier: "DateandLocationViewController" ) as! DateandLocationViewController
            vc.delegate = self
            navigationController.pushViewController(vc, animated: true)
        }
    }
}
extension IdentificationCoordinator: IdentificationFlowStepDelegate { func didFinishStep() { goToNextStep() } }
