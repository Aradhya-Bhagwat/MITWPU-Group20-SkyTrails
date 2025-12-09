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
    var viewModel: ViewModel = ViewModel()
    weak var delegate: IdentificationFlowStepDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set slider to 5 steps: 0,1,2,3,4
        birdSlider.minimumValue = 0
        birdSlider.maximumValue = 4
        birdSlider.isContinuous = true

        updateBirdDisplay(for: 0) // initial
        
        setupRightTickButton()
     

    }
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        let steppedValue = Int(round(sender.value)) // 0–4
        updateBirdDisplay(for: steppedValue)
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
    private func setupRightTickButton() {
        // Create button
        let button = UIButton(type: .system)
        
        // Circle background
        button.backgroundColor = .white
        button.layer.cornerRadius = 20   // for 40x40 size

        button.layer.masksToBounds = true   // important to remove rectangle
        
        // Checkmark icon
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = UIImage(systemName: "checkmark", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .black

        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Add tap action
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Put inside UIBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

  
    @objc private func nextTapped() {
        delegate?.didFinishStep()
    }
    
}
extension IdentificationSizeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}

