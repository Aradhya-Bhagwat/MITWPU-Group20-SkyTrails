import UIKit
import MapKit

protocol LocationDetailsDelegate: AnyObject {
    func removePin(at coordinate: CLLocationCoordinate2D)
    func startMovePin(at coordinate: CLLocationCoordinate2D)
}

class LocationDetailsViewController: UIViewController {

    var coordinate: CLLocationCoordinate2D!
    var locationName: String?
    var addressString: String?

    weak var delegate: LocationDetailsDelegate?

    @IBOutlet weak var grabberView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var detailsHeaderLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var coordsLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        configureContents()
        styleCancelButton()
    }

    private func setupAppearance() {
        grabberView.layer.cornerRadius = 3
        grabberView.backgroundColor = .systemGray3
        removeButton.layer.cornerRadius = 12
        removeButton.backgroundColor = .systemRed
        removeButton.setTitleColor(.white, for: .normal)
        moveButton.layer.cornerRadius = 12
        moveButton.backgroundColor = .systemGray5
        moveButton.setTitleColor(.label, for: .normal)
        detailsHeaderLabel.text = "Details"
    }

    private func configureContents() {
        titleLabel.text = locationName ?? "Location"
        addressLabel.text = addressString ?? "Loading address..."
        let lat = String(format: "%.5f° N", coordinate.latitude)
        let lon = String(format: "%.5f° E", coordinate.longitude)
        coordsLabel.text = "\(lat), \(lon)"
    }

    @IBAction func removeTapped(_ sender: Any) {
        delegate?.removePin(at: coordinate)
    }

    @IBAction func moveTapped(_ sender: Any) {
        delegate?.startMovePin(at: coordinate)
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true)
    }
    
    func styleCancelButton() {
    cancelButton.layer.cornerRadius = 16
        cancelButton.backgroundColor = UIColor.systemGray5
        cancelButton.tintColor = UIColor.label
        cancelButton.clipsToBounds = true
    }
}

