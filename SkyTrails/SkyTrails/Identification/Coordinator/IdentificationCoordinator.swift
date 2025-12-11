//
//  IdentificationCoordinator.swift
//  SkyTrails
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

class IdentificationCoordinator: Coordinator {
    var navigationController: UINavigationController
    
    let viewModel = ViewModel()
    private var steps: [IdentificationStep] = []
    private var currentIndex: Int = 0
    private var totalSteps: Int { steps.count  }
    private var currentStepNumber: Int { currentIndex }
    private var progressSteps: [IdentificationStep] = []
    
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start(){
        let storyboard = UIStoryboard.named("Identification")
        let vc = storyboard.instantiate(IdentificationViewController.self)
        
        vc.viewModel = self.viewModel
        vc.coordinator = self
        
        navigationController.setViewControllers([vc], animated: false)
    }
    
    func configureSteps(from options: [FieldMarkType]){
        steps.removeAll()
        let selected = options.filter { $0.isSelected ?? false }
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
        if selected.contains(where: { $0.fieldMarkName == "Field Marks" }) {
            steps.append(.gui)
        }
        
        steps.append(.result)
        
        progressSteps = steps.filter { step in
            switch step {
            case .gui, .result:
                return false
            default:
                return true
            }
        }
        
        currentIndex = 0
        goToNextStep()
    }
    
    func goDirectlyToResult() {
        let storyboard = UIStoryboard.named("Identification")
        let vc = storyboard.instantiate(ResultViewController.self)
        vc.viewModel = viewModel
        vc.delegate = self
        currentIndex = steps.count 
        navigationController.pushViewController(vc, animated: true)
    }
    
    func goDirectlyToResult(fromHistory historyItem: History, index: Int) {
        let storyboard = UIStoryboard.named("Identification")
        let vc = storyboard.instantiate(ResultViewController.self)
        
        vc.viewModel = viewModel
        vc.historyItem = historyItem
        vc.historyIndex = index
        vc.delegate = self
        
        navigationController.pushViewController(vc, animated: true)
    }

    func goDirectlyToResult(fromHistory historyItem: History) {
        let storyboard = UIStoryboard.named("Identification")
        let vc = storyboard.instantiate(ResultViewController.self)
        
        vc.viewModel = viewModel
        vc.historyItem = historyItem
        vc.delegate = self
        
        navigationController.pushViewController(vc, animated: true)
    }
    
    func LeftButton() {
        currentIndex = 0
        goToNextStep()
    }

    func goToNextStep(){
        
        if currentIndex >= steps.count {
                start()
                return
            }
        let step = steps[currentIndex]
        currentIndex += 1
        let screen: UIViewController
        let storyboard = UIStoryboard.named("Identification")
        
        switch step {
        case .dateLocation:
            let vc = storyboard.instantiate(DateandLocationViewController.self)
            vc.delegate = self
            vc.viewModel = viewModel
            screen = vc
        case .size:
            let vc = storyboard.instantiate(IdentificationSizeViewController.self)
            vc.delegate = self
            vc.viewModel = viewModel
            screen = vc
        case .shape:
            let vc = storyboard.instantiate(IdentificationShapeViewController.self)
            vc.delegate = self
            vc.viewModel = viewModel
            vc.selectedSizeIndex = viewModel.selectedSizeCategory
            screen = vc
        case .fieldMarks:
            let vc = storyboard.instantiate(IdentificationFieldMarksViewController.self)
            vc.delegate = self
            vc.viewModel = viewModel
            screen = vc
        case .gui:
            let vc = storyboard.instantiate(GUIViewController.self)
            vc.delegate = self
            vc.data = viewModel.data
            screen = vc
            
        case .result:
            let vc = storyboard.instantiate(ResultViewController.self)
            vc.delegate = self
            vc.viewModel = viewModel
            screen = vc
        }
        
        if let progressVC = screen as? (UIViewController & IdentificationProgressUpdatable),
           let idx = progressSteps.firstIndex(of: step) {

            let current = idx + 1
            let total = progressSteps.count

            progressVC.loadViewIfNeeded()
            progressVC.updateProgress(current: current, total: total)
        }

        navigationController.pushViewController(screen, animated: true)
    }
    
    func didTapShape() {

        let fieldMarksSelected = viewModel.fieldMarkOptions.contains {
            $0.fieldMarkName == "Field Marks" && ($0.isSelected ?? false)
        }

        let isLastDecisionStep = !steps.contains(.fieldMarks) && !steps.contains(.gui)

        if fieldMarksSelected {
            if let nextIndex = steps.firstIndex(of: .fieldMarks) {
                currentIndex = nextIndex
                goToNextStep()
            }
        }
        else if isLastDecisionStep {
            goDirectlyToResult()
        }
        else {

            goToNextStep()
        }
    }


}

extension IdentificationCoordinator: IdentificationFlowStepDelegate {
    func didTapLeftButton(){
        LeftButton()
    }
    
    func didTapShapes() {
       didTapShape()
    }
    
    func didFinishStep() { goToNextStep() }
}

