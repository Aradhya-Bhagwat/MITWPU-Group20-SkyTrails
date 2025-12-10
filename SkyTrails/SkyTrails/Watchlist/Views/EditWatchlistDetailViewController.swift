//
//  EditWatchlistDetailViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class EditWatchlistDetailViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var locationTextField: UITextField!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    @IBOutlet weak var inviteContactsView: UIView!
    
    // MARK: - Properties
    var viewModel: WatchlistViewModel?
    var watchlistType: WatchlistType = .custom
    weak var coordinator: WatchlistCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureViewBasedOnType()
        
        // Add Save Button
        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
        navigationItem.rightBarButtonItem = saveButton
    }

    private func setupUI() {
        self.title = "New Watchlist"
        view.backgroundColor = .systemGray6
        
        // Styling logic similar to UnobservedDetailViewController
        // Assuming outlets are connected and views exist
        // inviteContactsView styling
        if let inviteView = inviteContactsView {
            inviteView.layer.cornerRadius = 20
            inviteView.backgroundColor = .white
            inviteView.layer.shadowColor = UIColor.black.cgColor
            inviteView.layer.shadowOpacity = 0.08
            inviteView.layer.shadowOffset = CGSize(width: 0, height: 4)
            inviteView.layer.shadowRadius = 12
        }
    }

    private func configureViewBasedOnType() {
        switch watchlistType {
        case .custom, .myWatchlist:
            inviteContactsView.isHidden = true
        case .shared:
            inviteContactsView.isHidden = false
        }
    }

    @objc private func didTapSave() {
        guard let title = titleTextField.text, !title.isEmpty else {
            // Show alert
            return
        }
        
        let location = locationTextField.text ?? "Unknown"
        let startDate = startDatePicker.date
        let endDate = endDatePicker.date
        
        if watchlistType == .custom {
             // Create Custom Watchlist
             let newWatchlist = Watchlist(
                 title: title,
                 location: location,
                 startDate: startDate,
                 endDate: endDate,
                 observedBirds: [],
                 toObserveBirds: []
             )
             viewModel?.watchlists.append(newWatchlist)
             
        } else if watchlistType == .shared {
             // Create Shared Watchlist
             let newShared = SharedWatchlist(
                 title: title,
                 location: location,
                 dateRange: formatDateRange(start: startDate, end: endDate),
                 mainImageName: "bird_placeholder", // Default
                 stats: (0, 0),
                 userImages: ["person.circle.fill"] // Current User
             )
             viewModel?.sharedWatchlists.append(newShared)
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
