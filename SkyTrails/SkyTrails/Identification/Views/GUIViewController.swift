//
//  GUIViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 09/12/25.
//

import UIKit

class GUIViewController: UIViewController {
    weak var delegate: IdentificationFlowStepDelegate?
    var data: IdentificationData?
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var shapeLabel: UILabel!
    @IBOutlet weak var fieldMarksLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRightTickButton()
        updateUI()
        
    }
 
    private func updateUI() {
        guard let data = data else { return }
        
        dateLabel.text = data.date ?? "-"
      
        sizeLabel.text = data.size ?? "-"
        shapeLabel.text = data.shape ?? "-"
        
        if let marks = data.fieldMarks {
            fieldMarksLabel.text = marks.joined(separator: ", ")
        } else {
            fieldMarksLabel.text = "-"
        }
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
