import UIKit
import CoreLocation
import ImageIO

class ProfileLocationHeaderView: UIView {
    
    // MARK: - UI Components
    private let profileContainer = UIView()
    private let profileImageView = UIImageView()
    private let locationContainer = UIView()
    private let locationIconView = UIImageView()
    private let locationLabel = UILabel()
    
    // MARK: - Properties
    private let avatarMaxPixelSize: CGFloat = 512
    private var locationUpdateTask: Task<Void, Never>?
    private var authStateObserver: NSObjectProtocol?
    
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        observeUserSessionChanges()
        loadUserProfileImage()
        startLocationUpdates()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        observeUserSessionChanges()
        loadUserProfileImage()
        startLocationUpdates()
    }
    
    deinit {
        locationUpdateTask?.cancel()
        if let authStateObserver {
            NotificationCenter.default.removeObserver(authStateObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // Profile Container setup
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.backgroundColor = .systemBackground
        profileContainer.layer.cornerRadius = 22
        profileContainer.layer.borderWidth = 1
        profileContainer.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.2).cgColor
        addSubview(profileContainer)
        
        // Profile image setup
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 18
        profileImageView.image = UIImage(named: "defaultProfile")
        profileContainer.addSubview(profileImageView)
        
        // Location Container setup
        locationContainer.translatesAutoresizingMaskIntoConstraints = false
        locationContainer.backgroundColor = .systemBackground
        locationContainer.layer.cornerRadius = 22
        locationContainer.layer.borderWidth = 1
        locationContainer.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.2).cgColor
        addSubview(locationContainer)
        
        // Location icon setup
        locationIconView.translatesAutoresizingMaskIntoConstraints = false
        locationIconView.contentMode = .scaleAspectFit
        locationIconView.tintColor = .secondaryLabel
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        locationIconView.image = UIImage(systemName: "location.fill", withConfiguration: config)
        locationContainer.addSubview(locationIconView)
        
        // Location label setup
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.font = .systemFont(ofSize: 15, weight: .medium)
        locationLabel.textColor = .secondaryLabel
        locationLabel.text = "Loading..."
        locationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        locationContainer.addSubview(locationLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Profile Container
            profileContainer.topAnchor.constraint(equalTo: topAnchor),
            profileContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            profileContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            profileContainer.widthAnchor.constraint(equalToConstant: 44),
            profileContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Profile image
            profileImageView.centerXAnchor.constraint(equalTo: profileContainer.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: profileContainer.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 36),
            profileImageView.heightAnchor.constraint(equalToConstant: 36),
            
            // Location Container
            locationContainer.topAnchor.constraint(equalTo: topAnchor),
            locationContainer.leadingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: 8),
            locationContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            locationContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            locationContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Location icon
            locationIconView.leadingAnchor.constraint(equalTo: locationContainer.leadingAnchor, constant: 12),
            locationIconView.centerYAnchor.constraint(equalTo: locationContainer.centerYAnchor),
            locationIconView.widthAnchor.constraint(equalToConstant: 16),
            locationIconView.heightAnchor.constraint(equalToConstant: 16),
            
            // Location label
            locationLabel.leadingAnchor.constraint(equalTo: locationIconView.trailingAnchor, constant: 6),
            locationLabel.trailingAnchor.constraint(equalTo: locationContainer.trailingAnchor, constant: -16),
            locationLabel.centerYAnchor.constraint(equalTo: locationContainer.centerYAnchor)
        ])
        
        // Tap gestures
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(handleProfileTap))
        profileContainer.addGestureRecognizer(profileTap)
        profileContainer.isUserInteractionEnabled = true
        
        let locationTap = UITapGestureRecognizer(target: self, action: #selector(handleLocationTap))
        locationContainer.addGestureRecognizer(locationTap)
        locationContainer.isUserInteractionEnabled = true
        
        // Accessibility
        profileContainer.isAccessibilityElement = true
        profileContainer.accessibilityLabel = "Profile"
        profileContainer.accessibilityTraits = .button
        
        locationContainer.isAccessibilityElement = true
        locationContainer.accessibilityLabel = "Location"
        locationContainer.accessibilityTraits = .button
    }
    
    // MARK: - User Session
    private func observeUserSessionChanges() {
        authStateObserver = NotificationCenter.default.addObserver(
            forName: UserSession.authStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadUserProfileImage()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserProfileChange),
            name: UserSession.userProfileDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleUserProfileChange() {
        loadUserProfileImage()
    }
    
    // MARK: - Profile Image Loading
    private func loadUserProfileImage() {
        guard let user = UserSession.shared.getUser() else {
            profileImageView.image = UIImage(named: "defaultProfile")
            return
        }
        
        let photo = user.profilePhoto
        if photo.starts(with: "http") {
            loadImage(from: photo)
        } else if photo.starts(with: "file://") || FileManager.default.fileExists(atPath: photo) {
            loadLocalImage(from: photo)
        } else if !photo.isEmpty {
            profileImageView.image = UIImage(named: photo) ?? UIImage(named: "defaultProfile")
        } else {
            profileImageView.image = UIImage(named: "defaultProfile")
        }
    }
    
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = downsampledImage(from: data, maxPixelSize: avatarMaxPixelSize) {
                    await MainActor.run {
                        self.profileImageView.image = image
                    }
                }
            } catch {
                await MainActor.run {
                    self.profileImageView.image = UIImage(named: "defaultProfile")
                }
            }
        }
    }
    
    private func loadLocalImage(from pathOrURLString: String) {
        let fileURL = pathOrURLString.starts(with: "file://")
            ? URL(string: pathOrURLString)
            : URL(fileURLWithPath: pathOrURLString)
        
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]),
              let image = downsampledImage(from: data, maxPixelSize: avatarMaxPixelSize) else {
            profileImageView.image = UIImage(named: "defaultProfile")
            return
        }
        profileImageView.image = image
    }
    
    private func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Location Updates
    private func startLocationUpdates() {
        locationUpdateTask = Task { [weak self] in
            await self?.updateLocation()
            
            // Update location periodically
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await self?.updateLocation()
            }
        }
    }
    
    private func updateLocation() async {
        // Prefer user's explicitly saved home location over GPS
        if let savedName = await LocationPreferences.shared.homeLocationName {
            await MainActor.run {
                self.locationLabel.text = savedName
            }
            return
        }
        
        // Fall back to GPS location
        if let currentLocation = await LocationService.shared.currentLocation {
            let locationName = await LocationService.shared.reverseGeocode(
                lat: currentLocation.latitude,
                lon: currentLocation.longitude
            ) ?? "Current Location"
            
            await MainActor.run {
                self.locationLabel.text = locationName
            }
            return
        }
        
        // Fallback
        await MainActor.run {
            self.locationLabel.text = "Pune, India"
        }
    }
    
    // MARK: - Actions
    @objc private func handleProfileTap() {
        onTap?()
    }
    
    @objc private func handleLocationTap() {
        guard let topVC = window?.rootViewController?.topMostViewController() else { return }
        
        let storyboard = UIStoryboard(name: "LocationPicker", bundle: nil)
        if let pickerVC = storyboard.instantiateViewController(withIdentifier: "LocationPickerViewController") as? LocationPickerViewController {
            pickerVC.delegate = self
            let nav = UINavigationController(rootViewController: pickerVC)
            nav.modalPresentationStyle = .fullScreen
            topVC.present(nav, animated: true)
        }
    }
    
    // MARK: - Public Methods
    func refreshLocation() {
        locationUpdateTask?.cancel()
        startLocationUpdates()
    }
}

extension ProfileLocationHeaderView: LocationPickerDelegate {
    func didSelectLocation(name: String, lat: Double, lon: Double) {
        locationLabel.text = name
        // Optionally update LocationPreferences here if needed
        Task {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            await LocationPreferences.shared.setHomeLocation(coordinate, name: name)
        }
    }
}

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostViewController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        return self
    }
}
