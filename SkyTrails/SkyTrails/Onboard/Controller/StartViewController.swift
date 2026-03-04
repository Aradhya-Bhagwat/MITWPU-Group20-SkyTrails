//
//  OnboardViewController.swift
//  SkyTrails
//
//  Created by Aradhya Bhagwat on 11/01/26.
//

//
//  StartViewController.swift
//  SkyTrails
//

//
//  StartViewController.swift
//  SkyTrails
//

import UIKit

class StartViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var segmentOutlet: UISegmentedControl!
    @IBOutlet weak var loginSegmentView: UIView!
    @IBOutlet weak var signupSegmentView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.bringSubviewToFront(signupSegmentView)
    }

    // MARK: - Segment Control

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {

        if sender.selectedSegmentIndex == 0 {
            view.bringSubviewToFront(signupSegmentView)
        } else {
            view.bringSubviewToFront(loginSegmentView)
        }
    }
}
