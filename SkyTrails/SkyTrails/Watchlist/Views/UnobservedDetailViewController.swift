import UIKit
import MapKit
import CoreLocation

class UnobservedDetailViewController: UIViewController {
	
		    // MARK: - Data Dependency
		    // This is how we pass data into this screen
		    var bird: Bird?
            var watchlistId: UUID?
		    weak var coordinator: WatchlistCoordinator?
    
            // Autocomplete State
            private var searchCompleter = MKLocalSearchCompleter()
            private var locationResults: [MKLocalSearchCompletion] = []
            private var activeTextField: UITextField?
            
            private lazy var suggestionsTableView: UITableView = {
                let tv = UITableView()
                tv.translatesAutoresizingMaskIntoConstraints = false
                tv.backgroundColor = .white
                tv.layer.cornerRadius = 12
                tv.layer.shadowColor = UIColor.black.cgColor
                tv.layer.shadowOpacity = 0.1
                tv.layer.shadowOffset = CGSize(width: 0, height: 4)
                tv.layer.shadowRadius = 8
                tv.isHidden = true
                tv.delegate = self
                tv.dataSource = self
                tv.separatorStyle = .none
                tv.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell")
                return tv
            }()
		    
		    // MARK: - IBOutlets
		    // Connect these to your Storyboard elements
		    @IBOutlet weak var birdImageView: UIImageView!
		    @IBOutlet weak var startLabel: UILabel! // The label inside the Start Date row
		    @IBOutlet weak var endLabel: UILabel!   // The label inside the End Date row
		    @IBOutlet weak var startDatePicker: UIDatePicker!
		    @IBOutlet weak var endDatePicker: UIDatePicker!
		    @IBOutlet weak var notesTextView: UITextView!
		    @IBOutlet weak var searchTextField: UITextField!
            @IBOutlet weak var detailsCardView: UIView!
            @IBOutlet weak var locationCardView: UIView!
		    
		    // MARK: - Lifecycle
		    override func viewDidLoad() {
		        super.viewDidLoad()
                self.title = bird?.name
                
                // Display empty/default fields for observation data
                // Example: observationField.text = ""
		        
		        // 1. Setup the visual styling (Round corners, shadows)
		        setupStyling()
                setupAutocomplete()
		        
		        // 2. Load the data if it exists
		        if let birdData = bird {
		            configure(with: birdData)
                    setupRightBarButtons()
		        } else {
                    // Only show Save for new birds (or setup menu without delete? logic depends on requirement, usually delete is for existing)
                    let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
                    navigationItem.rightBarButtonItem = saveButton
                }
		    }
    
            private func setupRightBarButtons() {
                let deleteButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(didTapDelete))
                deleteButton.tintColor = .systemRed // Optional: Make trash icon red
                
                let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(didTapSave))
                
                // Order: Right to Left -> [Save, Delete]
                navigationItem.rightBarButtonItems = [saveButton, deleteButton]
            }
            
            @objc private func didTapDelete() {
                deleteBird()
            }
            
            private func deleteBird() {
                guard let birdToDelete = bird, let id = watchlistId else { return }
                
                let alert = UIAlertController(title: "Delete Bird", message: "Are you sure you want to delete this bird from your watchlist?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
                    self?.coordinator?.viewModel?.deleteBird(birdToDelete, from: id)
                    self?.navigationController?.popViewController(animated: true)
                }))
                present(alert, animated: true)
            }
    
            private func setupAutocomplete() {
                searchCompleter.delegate = self
                searchTextField.delegate = self
                
                // Add TableView to view hierarchy
                view.addSubview(suggestionsTableView)
                view.bringSubviewToFront(suggestionsTableView)
            }
            
            private func updateSuggestionsLayout() {
                guard let activeTF = activeTextField, !suggestionsTableView.isHidden else { return }
                
                // Convert text field frame to main view coordinates
                let frame = activeTF.convert(activeTF.bounds, to: view)
                
                // Update constraints (remake them)
                suggestionsTableView.removeConstraints(suggestionsTableView.constraints)
                view.removeConstraints(view.constraints.filter { $0.firstItem as? UIView == suggestionsTableView })
                
                NSLayoutConstraint.activate([
                    suggestionsTableView.topAnchor.constraint(equalTo: view.topAnchor, constant: frame.maxY + 4),
                    suggestionsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: frame.minX),
                    suggestionsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(view.bounds.width - frame.maxX)),
                    suggestionsTableView.heightAnchor.constraint(equalToConstant: 200) // Fixed height for suggestions
                ])
            }
		    
		    @objc func didTapSave() {
		        guard var updatedBird = bird else { return }
		        
		        // Update dates
		        updatedBird.date = [startDatePicker.date, endDatePicker.date]
		        
		        // Update location (simple string append/replace for now)
		        if let loc = searchTextField.text, !loc.isEmpty {
		            updatedBird.location = [loc]
		        }
		        
		        coordinator?.saveBirdDetails(bird: updatedBird)
		    }
		    
		    // MARK: - Data Population
            func configure(with bird: Bird) {
			// 1. Set Navigation Title
		self.navigationItem.title = "Add new species"
		
			// 2. Load Image (Safely)
		if let imageName = bird.images.first {
            if let assetImage = UIImage(named: imageName) {
                birdImageView.image = assetImage
            } else {
                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(imageName)
                if let docImage = UIImage(contentsOfFile: fileURL.path) {
                    birdImageView.image = docImage
                } else {
                    birdImageView.image = UIImage(systemName: "photo")
                }
            }
		} else {
				// Fallback if array is empty
			birdImageView.image = UIImage(systemName: "photo")
		}
		
			// 3. Set Dates
			// Logic: Use first date for Start, last date for End.
			// If only 1 date exists, use it for both.
		if let firstDate = bird.date.first {
			startDatePicker.date = firstDate
		}
		
		if let lastDate = bird.date.last {
			endDatePicker.date = lastDate
		}
		
			// 4. Set Location
			// Pre-fill the search bar with the saved location
		if let locationName = bird.location.first {
			searchTextField.text = locationName
		}
		
			// 5. Notes?
			// Your Bird model currently doesn't have a 'notes' field.
			// I have left the placeholder text, but if you add 'var notes: String?'
			// to your model later, map it here:
			// notesTextView.text = bird.notes ?? "Add notes..."
	}
	
		// MARK: - Styling (From previous step)
	func setupStyling() {
			// 1. Background
		view.backgroundColor = .systemGray6 // Light gray background
		
			// 2. Bird Image
		birdImageView.layer.cornerRadius = 24
		birdImageView.clipsToBounds = true
		
			// 3. Search Bar Styling
		searchTextField.layer.cornerRadius = 25 // Pill shape (half of height 50)
		searchTextField.clipsToBounds = true
			// Add a subtle shadow to the search bar
		searchTextField.layer.shadowColor = UIColor.black.cgColor
		searchTextField.layer.shadowOpacity = 0.05
		searchTextField.layer.shadowOffset = CGSize(width: 0, height: 2)
		searchTextField.layer.shadowRadius = 4
		searchTextField.layer.masksToBounds = false // Needed for shadow
		
			// 4. Cards (Details & Location) styling helper
		styleCard(detailsCardView)
		styleCard(locationCardView)
	}
	
	func styleCard(_ view: UIView) {
		view.layer.cornerRadius = 20
		view.backgroundColor = .white
		
			// The Elite Shadow
		view.layer.shadowColor = UIColor.black.cgColor
		view.layer.shadowOpacity = 0.08
		view.layer.shadowOffset = CGSize(width: 0, height: 4)
		view.layer.shadowRadius = 12
		view.layer.masksToBounds = false
	}
}

// MARK: - Text Field & Autocomplete Delegate
extension UnobservedDetailViewController: UITextFieldDelegate, MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
        updateSuggestionsLayout()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) else { return true }
        searchCompleter.queryFragment = text
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             self.suggestionsTableView.isHidden = true
        }
    }
    
    // MARK: - MapKit Delegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        locationResults = completer.results
        suggestionsTableView.isHidden = locationResults.isEmpty
        suggestionsTableView.reloadData()
        updateSuggestionsLayout()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Handle error if needed
    }
    
    // MARK: - Table View Data Source
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
        cell.backgroundColor = .white
        cell.textLabel?.textColor = .black
        
        let result = locationResults[indexPath.row]
        cell.textLabel?.text = result.title + ", " + result.subtitle
        
        return cell
    }
    
    // MARK: - Table View Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let result = locationResults[indexPath.row]
        
        // Perform search to get full details
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { [weak self] (response, error) in
            guard let self = self else { return }
            
            let fullAddress = result.title + " " + result.subtitle
            self.searchTextField.text = fullAddress
            self.suggestionsTableView.isHidden = true
            self.activeTextField?.resignFirstResponder()
        }
    }
}
