//
//  OnboardViewController.swift
//  SkyTrails
//
//  Created by Aradhya Bhagwat on 11/01/26.
//

import UIKit

class OnboardViewController: UIViewController {

    @IBOutlet weak var segmentOutlet: UISegmentedControl!
    
    @IBOutlet weak var loginSegmentView: UIView!
    @IBOutlet weak var signupSegmentView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.bringSubviewToFront(signupSegmentView)
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            self.view.bringSubviewToFront(loginSegmentView)
        case 0:
            self.view.bringSubviewToFront(signupSegmentView)
        default:
            break
        }
        
        
    }
    

}
