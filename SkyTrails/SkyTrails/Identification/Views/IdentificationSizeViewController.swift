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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set slider to 5 steps: 0,1,2,3,4
        birdSlider.minimumValue = 0
        birdSlider.maximumValue = 4
        birdSlider.isContinuous = true
        birdSlider.isContinuous = true

        updateBirdDisplay(for: 0) // initial
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
}

