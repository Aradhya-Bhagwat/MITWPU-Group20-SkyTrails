
import UIKit
import MapKit

class CommunityObservationViewController: UIViewController {

    @IBOutlet weak var birdImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var likesCountLabel: UILabel!
    @IBOutlet weak var likeIconImageView: UIImageView!
    @IBOutlet weak var locationNameLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var timePicker: UIDatePicker!
    @IBOutlet weak var dateCardView: UIView!
    @IBOutlet weak var locationStackView: UIStackView!
    
    var observation: CommunityObservation?
    var observationId: String?
    private var locationBackgroundView: UIView?
    private var isLiked: Bool = false
    private var currentLikes: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()

        navigationItem.largeTitleDisplayMode = .never
        
        birdImageView.layer.cornerRadius = 24
        birdImageView.clipsToBounds = true
        
        locationStackView.isLayoutMarginsRelativeArrangement = true
        // Set layout margins so map goes edge to edge at the bottom and sides
        locationStackView.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)

        // Ensure the internal stack view for the label has horizontal padding
        if let labelStack = locationStackView.arrangedSubviews.first as? UIStackView {
            labelStack.isLayoutMarginsRelativeArrangement = true
            labelStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
        
        // Ensure map matches corner radius at the bottom
        mapView.layer.cornerRadius = 20
        mapView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        mapView.clipsToBounds = true

        setupStackBackgrounds()
        setupLikeAction()
        applySemanticAppearance()
        
        if let obs = observation {
            configureView(with: obs)
        } else if let id = observationId {
            loadData(for: id)
        }
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
    }
    
    private func setupStackBackgrounds() {
        locationBackgroundView = locationStackView.ensureBackgroundView()
        locationBackgroundView?.layer.cornerRadius = 20
    }
    
    private func setupLikeAction() {
        likeIconImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(likeIconTapped))
        likeIconImageView.addGestureRecognizer(tapGesture)
        
        // initialize values
        currentLikes = 24
        isLiked = true // Based on the storyboard showing "heart.fill"
        updateLikeUI()
    }
    
    @objc private func likeIconTapped() {
        isLiked.toggle()
        currentLikes += isLiked ? 1 : -1
        
        updateLikeUI()
        animateLikeIcon()
    }
    
    private func updateLikeUI() {
        likesCountLabel.text = "\(currentLikes)"
        let imageName = isLiked ? "heart.fill" : "heart"
        likeIconImageView.image = UIImage(systemName: imageName)
        likeIconImageView.tintColor = isLiked ? .systemRed : .secondaryLabel
    }
    
    private func animateLikeIcon() {
        UIView.animate(withDuration: 0.1, animations: {
            self.likeIconImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                self.likeIconImageView.transform = .identity
            }, completion: nil)
        }
    }
    
    func loadData(for id: String) {
    }
    
    private func configureView(with observation: CommunityObservation) {
        self.title = observation.displayBirdName
        
        if let image = UIImage(named: observation.displayImageName) {
            birdImageView.image = image
        } else {
            birdImageView.image = UIImage(systemName: "photo")
        }
        
        userNameLabel.text = "by \(observation.username)"
        locationNameLabel.numberOfLines = 0
        locationNameLabel.text = observation.location
        
        datePicker.date = observation.observedAt
        timePicker.date = observation.observedAt
        datePicker.isUserInteractionEnabled = false
        timePicker.isUserInteractionEnabled = false
        
        if let lat = observation.lat, let lon = observation.lon {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
            mapView.setRegion(region, animated: false)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = observation.location
            mapView.addAnnotation(annotation)
        }
    }

    private func applySemanticAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let cardColor: UIColor = isDarkMode ? .secondarySystemBackground : .systemBackground

        view.backgroundColor = .systemBackground
        dateCardView.backgroundColor = cardColor
        dateCardView.layer.cornerRadius = 20
        dateCardView.layer.masksToBounds = false

        locationBackgroundView?.backgroundColor = cardColor
        locationBackgroundView?.layer.masksToBounds = false

        [userNameLabel, locationNameLabel].forEach { $0?.textColor = .label }
        datePicker.tintColor = .systemBlue
        timePicker.tintColor = .systemBlue
        datePicker.overrideUserInterfaceStyle = .unspecified
        timePicker.overrideUserInterfaceStyle = .unspecified

        if isDarkMode {
            [dateCardView, locationBackgroundView].forEach { view in
                view?.layer.shadowOpacity = 0
                view?.layer.shadowRadius = 0
                view?.layer.shadowOffset = .zero
                view?.layer.shadowPath = nil
            }
        } else {
            [dateCardView, locationBackgroundView].forEach { view in
                view?.layer.shadowColor = UIColor.black.cgColor
                view?.layer.shadowOpacity = 0.08
                view?.layer.shadowOffset = CGSize(width: 0, height: 4)
                view?.layer.shadowRadius = 12
                view?.layer.shadowPath = nil
            }
        }
    }
}

extension UIStackView {
    func ensureBackgroundView() -> UIView {
        if let existing = subviews.first(where: { $0.tag == 9991 }) {
            return existing
        }
        let subView = UIView(frame: bounds)
        subView.tag = 9991
        subView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(subView, at: 0)
        return subView
    }
}
