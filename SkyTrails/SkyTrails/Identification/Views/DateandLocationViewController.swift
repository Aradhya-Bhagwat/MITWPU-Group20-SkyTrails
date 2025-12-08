//
//  DateandLocationViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class DateandLocationViewController: UIViewController,UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableContainerView: UIView!
    @IBOutlet weak var dateandlocationTableView: UITableView!
    weak var delegate: IdentificationFlowStepDelegate?

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
    
    func numberOfSections(in tableView: UITableView) -> Int {
       return 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 || section == 1 {
            return 1
        }
        return 2
    }


    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as! DateInputCell
            cell.configure(withTitle: "Date", date: Date())
            cell.delegate = self
            cell.selectionStyle = .none
            return cell
        }
      
      
        if indexPath.section == 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SearchCell", for: indexPath)
                return cell
            }
      let  cell = UITableViewCell(style: .default, reuseIdentifier: "location_cell")
            
            if indexPath.row == 1 {
                cell.textLabel?.text = "Current Location"
                cell.imageView?.image = UIImage(systemName: "location.fill")
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Map"
                cell.imageView?.image = UIImage(systemName: "map")
            }
   
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "DateInputCell", bundle: nil)
          dateandlocationTableView.register(nib, forCellReuseIdentifier: "DateInputCell")
      
          dateandlocationTableView.delegate = self
          dateandlocationTableView.dataSource = self
        styleTableContainer()
        setupRightTickButton()
    

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
extension DateandLocationViewController: DateInputCellDelegate {

    func dateInputCell(_ cell: DateInputCell, didPick date: Date) {
        print("Selected Date:", date)
     
    }
}

