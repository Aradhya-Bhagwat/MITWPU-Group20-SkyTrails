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
    @IBOutlet weak var progressView: UIProgressView!
    var viewModel: ViewModel!
    weak var delegate: IdentificationFlowStepDelegate?
    var selectedDate: Date?


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
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
        let nib = UINib(nibName: "DateInputCell", bundle: nil)
          dateandlocationTableView.register(nib, forCellReuseIdentifier: "DateInputCell")
      
          dateandlocationTableView.delegate = self
          dateandlocationTableView.dataSource = self
        styleTableContainer()
        setupRightTickButton()
        
        // Initialize with today's date so it's not nil if user clicks Next immediately
        selectedDate = Date() 
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
    func formatDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"   // Example: 09 Dec 2025
        return formatter.string(from: date)
    }

    @objc private func nextTapped() {
        let formattedDate = formatDate(selectedDate)

        
        // Simulating location selection for now as the UI doesn't fully implement the picker logic yet.
        // In a real app, this would come from the selected cell or map.
        // Using a valid location from bird_database.json for testing.
        let location = "Pune, India"

			// Inside nextTapped()
		viewModel.data.date = formattedDate       // Needed for Summary
		viewModel.data.location = location        // Needed for Summary
		viewModel.selectedLocation = location     // Needed for Filtering
		
        // Trigger intermediate filtering
        viewModel.filterBirds(
            shape: viewModel.selectedShapeId,
            size: viewModel.selectedSizeCategory,
            location: viewModel.selectedLocation,
            fieldMarks: []
        )
        
        delegate?.didFinishStep()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       
        if indexPath.section == 2 && indexPath.row == 0 {
             print("Map tapped")
             delegate?.openMapScreen()
             return
         }
         
       
         if indexPath.section == 2 && indexPath.row == 1 {
             print("Current Location tapped")
         }

    }

}
extension DateandLocationViewController: DateInputCellDelegate, IdentificationProgressUpdatable {

    func dateInputCell(_ cell: DateInputCell, didPick date: Date) {
        print("Selected Date:", date)
        selectedDate = date
     
    }
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}


