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
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.baseBackgroundColor = .white
            config.baseForegroundColor = .black
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            let image = UIImage(systemName: "checkmark", withConfiguration: symbolConfig)
            config.image = image

            button.configuration = config
            // Ensure rounded look with explicit size
            button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            button.layer.cornerRadius = 20
            button.layer.masksToBounds = true
        } else {
            // Fallback for iOS < 15
            button.backgroundColor = .white
            button.layer.cornerRadius = 20   // for 40x40 size
            button.layer.masksToBounds = true

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            let image = UIImage(systemName: "checkmark", withConfiguration: symbolConfig)
            button.setImage(image, for: .normal)
            button.tintColor = .black
        }

        // Add tap action
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Put inside UIBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }
    @objc private func nextTapped() {
        delegate?.didFinishStep()
    }
}
