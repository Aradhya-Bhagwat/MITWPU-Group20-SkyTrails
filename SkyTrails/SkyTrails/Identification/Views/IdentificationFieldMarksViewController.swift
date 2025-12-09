//
//  FieldMarksViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class IdentificationFieldMarksViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {

    
    @IBOutlet weak var tableContainerView: UIView!
    
    @IBOutlet weak var fieldMarkTableView: UITableView!
    
    @IBOutlet weak var progressView: UIProgressView!

    weak var delegate: IdentificationFlowStepDelegate?
    var selectedFieldMarks: [Int] = []

    var viewModel: ViewModel = ViewModel()
    func styleTableContainer() {
        tableContainerView.backgroundColor = .white
        tableContainerView.layer.cornerRadius = 12
        tableContainerView.layer.shadowColor = UIColor.black.cgColor
        tableContainerView.layer.shadowOpacity = 0.1
        tableContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        tableContainerView.layer.shadowRadius = 8
        tableContainerView.layer.masksToBounds = false
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.fieldMarks.count
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
   

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fieldmark_cell", for: indexPath)
        let item = viewModel.fieldMarks[indexPath.row]
        cell.textLabel?.text = item.name
        if let img = UIImage(named: item.imageView) {
    
            let targetSize = CGSize(width: 60, height: 60)
            let resized = resize(img, to: targetSize)
            cell.imageView?.image = resized
            cell.imageView?.contentMode = .scaleAspectFill
            cell.imageView?.frame = CGRect(origin: .zero, size: targetSize)
        } else {
            cell.imageView?.image = nil
        }
        let toggle = UISwitch()
        toggle.tag = indexPath.row

        toggle.isOn = selectedFieldMarks.contains(indexPath.row)

        toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        styleTableContainer()
        fieldMarkTableView.delegate = self
        fieldMarkTableView.dataSource = self
        setupRightTickButton()

    }
    @objc func switchChanged(_ sender: UISwitch) {
        let index = sender.tag

        if sender.isOn {
            if selectedFieldMarks.count >= 5 {
                sender.setOn(false, animated: true)
                showMaxLimitAlert()
                return
            }
            if !selectedFieldMarks.contains(index) {
                selectedFieldMarks.append(index)
            }
        } else {
            // Remove index
            if let position = selectedFieldMarks.firstIndex(of: index) {
                selectedFieldMarks.remove(at: position)
            }
        }

        print("Selected indices = \(selectedFieldMarks)")
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
      
        
    
        

        
    }
    
    private func showMaxLimitAlert() {
        let alert = UIAlertController(
            title: "Limit Reached",
            message: "You can select at most 5 field marks.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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

extension IdentificationFieldMarksViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
