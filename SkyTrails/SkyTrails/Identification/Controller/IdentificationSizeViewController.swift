//
//  Identification1ViewController.swift
//  SkyTrails
//
//  Created by MIT WPU on 26/11/25.
//

import UIKit

class IdentificationSizeViewController: UIViewController {

    @IBOutlet weak var birdImage: UIImageView!
    @IBOutlet weak var birdSlider: UISlider!
    @IBOutlet weak var birdLabel: UILabel!
    
    @IBOutlet weak var progressView: UIProgressView!
    var selectedSize: String?

    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set slider to 5 steps: 0,1,2,3,4
        birdSlider.minimumValue = 0
        birdSlider.maximumValue = 4
        birdSlider.isContinuous = true
        viewModel.selectedSizeCategory = 0
        updateBirdDisplay(for: 0)
        setupRightTickButton()
             
      
    }
 
    @IBAction func sliderChanged(_ sender: UISlider) {
       let steppedValue = Int(round(sender.value)) 
        updateBirdDisplay(for: steppedValue)
        viewModel.selectedSizeCategory = steppedValue
    }
    private func setupRightTickButton() {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "checkmark", withConfiguration: config), for: .normal)
        button.tintColor = .black
        
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }
    private func updateBirdDisplay(for index: Int) {
        switch index {
                case 0:
                    birdLabel.text = "Less than 6 inches"
                case 1:
                    birdLabel.text = "6–14 inches"
                case 2:
                    birdLabel.text = "14–25 inches"
                case 3:
                    birdLabel.text = "25–59 inches"
                case 4:
                    birdLabel.text = "59 inches and over"
                default:
                    birdLabel.text = ""
                }
                
                let imageName = "bird\(index)"
                birdImage.image = UIImage(named: imageName)
            }

    func sizeDescription(for index: Int) -> String {
        switch index {
        case 0: return "Less than 6 inches"
        case 1: return "6–14 inches"
        case 2: return "14–25 inches"
        case 3: return "25–59 inches"
        case 4: return "59 inches and over"
        default: return ""
        }
    }

    @objc private func nextTapped() {
        // 1. Update ViewModel state
        viewModel.selectedSizeCategory = Int(round(birdSlider.value))
        
        // 2. Trigger intermediate filtering
        viewModel.filterBirds(
            shape: viewModel.selectedShapeId,
            size: viewModel.selectedSizeCategory,
            location: viewModel.selectedLocation,
            fieldMarks: []
        )
        
        // 3. Update data for GUI display
        let sizeText = sizeDescription(for: viewModel.selectedSizeCategory ?? 0)
			// Inside nextTapped()
		viewModel.data.size = sizeText            // Needed for Summary
		viewModel.selectedSizeCategory = Int(round(birdSlider.value)) // Needed for Filtering
        
        delegate?.didFinishStep()
    }
    
}
extension IdentificationSizeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}

