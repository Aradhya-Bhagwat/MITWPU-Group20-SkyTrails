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
    
    let viewModel = ViewModel()
    private var steps: [IdentificationStep] = []
    private var currentIndex: Int = 0
    private var totalSteps: Int { steps.count }
    private var currentStepNumber: Int { currentIndex }

    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start(){
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "IdentificationViewController") as! IdentificationViewController
        vc.viewModel = viewModel
        vc.coordinator = self
        navigationController.setViewControllers([vc], animated: true)
        
    }
    
    func configureSteps(from options: [FieldMarkType]){
        steps.removeAll()
        for option in options where option.isSelected ?? false {
            switch option.fieldMarkName {
            case "Location & Date":
                steps.append(.dateLocation)
            case "Size":
                steps.append(.size)
            case "Shape":
                steps.append(.shape)
            case "Field Marks":
                steps.append(.fieldMarks)
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
        let screen: UIViewController
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        switch step {
            case .dateLocation:
            let vc = storyboard.instantiateViewController( withIdentifier: "DateandLocationViewController" ) as! DateandLocationViewController
            vc.delegate = self
            vc.viewModel = viewModel
            screen = vc
            case .size:
                let vc = storyboard.instantiateViewController( withIdentifier: "IdentificationSizeViewController" ) as! IdentificationSizeViewController
                vc.delegate = self
                vc.viewModel = viewModel
               screen = vc
            case .shape:
                let vc = storyboard.instantiateViewController( withIdentifier: "IdentificationShapeViewController" ) as! IdentificationShapeViewController
                vc.delegate = self
            vc.viewModel = viewModel
                screen = vc
            case .fieldMarks:
                let vc = storyboard.instantiateViewController( withIdentifier: "IdentificationFieldMarksViewController" ) as! IdentificationFieldMarksViewController
                vc.delegate = self
            vc.viewModel = viewModel
            screen = vc
        }
        if let progressVC = screen as? (UIViewController & IdentificationProgressUpdatable) {

            progressVC.loadViewIfNeeded()   // Now valid!
            
            progressVC.updateProgress(
                current: currentIndex,
                total: steps.count
            )
        }

        navigationController.pushViewController(screen, animated: true)

    }
}
extension IdentificationCoordinator: IdentificationFlowStepDelegate { func didFinishStep() { goToNextStep() } }
