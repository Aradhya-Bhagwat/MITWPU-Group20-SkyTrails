import UIKit
import Photos
import AVFoundation
import ImageIO

import SwiftUI

class ProfileViewController: UIViewController,
                             UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {

    // MARK: - Outlets

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!

    // MARK: - Properties

    private let avatarMaxPixelSize: CGFloat = 512

    private let actionsStack = UIStackView()
    private let aboutLabel = UILabel()
    private let versionLabel = UILabel()
    
    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.hidesBottomBarWhenPushed = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureUI()
        configureActions()
        loadUser()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: NSNotification.Name("UserProfileDidChange"), object: nil)
    }

    @objc private func handleProfileUpdate() {
        DispatchQueue.main.async {
            self.loadUser()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        profileImageView.layer.cornerRadius = profileImageView.bounds.width / 2
        logoutButton.layer.cornerRadius = 24
    }

    // MARK: - UI Setup

    private func configureUI() {

        view.backgroundColor = .systemBackground

        // Remove from storyboard to clear constraints and re-add for programmatic layout
        let elements = [profileImageView, nameLabel, emailButton, logoutButton]
        elements.forEach { $0?.removeFromSuperview() }
        elements.forEach { if let el = $0 { view.addSubview(el) } }

        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.isUserInteractionEnabled = true

        nameLabel.font = .preferredFont(forTextStyle: .title1)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textAlignment = .center

        // Email button style - now clearly an interactive element
        emailButton.configuration = .filled()
        emailButton.configuration?.baseBackgroundColor = .systemBlue.withAlphaComponent(0.12)
        emailButton.configuration?.baseForegroundColor = .systemBlue
        emailButton.configuration?.cornerStyle = .capsule
        emailButton.configuration?.image = UIImage(systemName: "bird.fill")
        emailButton.configuration?.imagePadding = 10

        emailButton.setContentHuggingPriority(.required, for: .horizontal)

        styleLogoutButton()

        setupTopProfileConstraints()
        setupActionRows()
        setupLogoutButton()
        setupFooter()
        setupFooterConstraints()

        addProfileImageTap()
    }

    private func configureActions() {
        emailButton.addTarget(self, action: #selector(emailTapped), for: .touchUpInside)
    }

    // MARK: - Top Profile Layout

    private func setupTopProfileConstraints() {

        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        emailButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            profileImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            profileImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 120),
            profileImageView.heightAnchor.constraint(equalToConstant: 120),

            nameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            emailButton.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 14),
            emailButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emailButton.heightAnchor.constraint(equalToConstant: 44),
            emailButton.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
    }

    // MARK: - Load User

    private func loadUser() {

        guard let user = UserSession.shared.getUser() else {
            logout()
            return
        }

        nameLabel.text = user.name
        emailButton.setTitle(user.email, for: .normal)

        if user.profilePhoto.starts(with: "http") {
            loadRemoteImage(user.profilePhoto)

        } else if FileManager.default.fileExists(atPath: user.profilePhoto) {
            loadLocalImage(user.profilePhoto)

        } else {
            profileImageView.image = UIImage(named: "defaultProfile")
        }
    }

    // MARK: - Mini-Game

    @objc private func emailTapped() {
        // Remove standard sharing and present the polished SwiftUI game view instead
        let gameView = MigrationGameView()
        let hostingController = UIHostingController(rootView: gameView)
        hostingController.modalPresentationStyle = .fullScreen
        hostingController.modalTransitionStyle = .coverVertical
        
        present(hostingController, animated: true)
    }

    // MARK: - Logout
    @IBAction func logoutTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Logout",
                                      message: "Are you sure you want to log out of SkyTrails?",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.logout()
        })
        
        present(alert, animated: true, completion: nil)
    }

    private func logout() {

        if let token = UserSession.shared.getAccessToken() {
            Task { try? await SupabaseAuthService.shared.signOut(accessToken: token) }
        }

        UserSession.shared.logout()
        goToLogin()
    }

    private func goToLogin() {

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

        let storyboard = UIStoryboard(name: "Onboard", bundle: nil)
        let startVC = storyboard.instantiateViewController(withIdentifier: "StartViewController")

        UIView.transition(with: window,
                          duration: 0.3,
                          options: .transitionFlipFromLeft,
                          animations: {
                              window.rootViewController = startVC
                          })
    }

    // MARK: - Image Loading

    private func loadRemoteImage(_ urlString: String) {

        guard let url = URL(string: urlString) else { return }

        DispatchQueue.global().async {

            if let data = try? Data(contentsOf: url),
               let image = self.downsampleImage(data) {

                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            }
        }
    }

    private func loadLocalImage(_ path: String) {

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let image = downsampleImage(data) else {

            profileImageView.image = UIImage(named: "defaultProfile")
            return
        }

        profileImageView.image = image
    }

    // MARK: - Image Picker

    private func addProfileImageTap() {

        let tap = UITapGestureRecognizer(target: self, action: #selector(profileImageTapped))
        profileImageView.addGestureRecognizer(tap)
    }

    @objc private func profileImageTapped() {

        let sheet = UIAlertController(title: "Profile Photo",
                                      message: "Choose source",
                                      preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            self.openCamera()
        })

        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.openLibrary()
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(sheet, animated: true)
    }

    private func openCamera() {

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showMessage("Camera not available")
            return
        }

        presentPicker(.camera)
    }

    private func openLibrary() {
        presentPicker(.photoLibrary)
    }

    private func presentPicker(_ source: UIImagePickerController.SourceType) {

        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        picker.allowsEditing = true

        present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        picker.dismiss(animated: true)

        guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }

        profileImageView.image = image
        saveProfileImage(image)
    }

    // MARK: - Save Image

    private func saveProfileImage(_ image: UIImage) {

        guard let jpeg = image.jpegData(compressionQuality: 0.8),
              let user = UserSession.shared.getUser() else { return }

        let fileName = "profile_\(user.user_id.uuidString).jpg"

        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        try? jpeg.write(to: url)

        var updated = user
        updated.profilePhoto = url.path

        UserSession.shared.saveUser(updated)
        
        Task {
            do {
                let publicUrl = try await UserSyncService.shared.uploadProfilePhoto(data: jpeg, user_id: user.user_id)
                updated.profilePhoto = publicUrl
                UserSession.shared.saveUser(updated)
                try await UserSyncService.shared.upsertUser(updated)
            } catch {
                print("DEBUG: Profile photo upload/sync failed: \(error)")
            }
        }
    }

    // MARK: - Action Rows

    private func setupActionRows() {

        actionsStack.axis = .vertical
        actionsStack.spacing = 12
        actionsStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(actionsStack)

        actionsStack.addArrangedSubview(makeRow("Edit Profile", "pencil", #selector(editProfile)))
        actionsStack.addArrangedSubview(makeRow("Settings", "gear", #selector(openSettings)))
        actionsStack.addArrangedSubview(makeRow("Share Profile", "square.and.arrow.up", #selector(shareProfileTapped)))

        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: emailButton.bottomAnchor, constant: 20),
            actionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            actionsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func makeRow(_ title: String, _ icon: String, _ action: Selector) -> UIView {

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let iconImage = UIImageView(image: UIImage(systemName: icon))
        iconImage.tintColor = .systemBlue

        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .systemBlue

        let leftStack = UIStackView(arrangedSubviews: [iconImage, label])
        leftStack.axis = .horizontal
        leftStack.spacing = 12
        leftStack.alignment = .center

        leftStack.translatesAutoresizingMaskIntoConstraints = false
        chevron.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(leftStack)
        container.addSubview(chevron)

        NSLayoutConstraint.activate([
            leftStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            leftStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            chevron.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])

        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))

        return container
    }

    @objc private func editProfile() {
        let editVC = EditProfileViewController()
        editVC.onProfileUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.loadUser()
            }
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(ProfileSettingsViewController(), animated: true)
    }

    @objc private func shareProfileTapped() {

        let message = """
🌟 Join me on SkyTrails! 🐦

SkyTrails helps you track and predict bird migrations, discover rare sightings, and explore the wonders of the avian world. 🌍✨

Check it out and join the community here:
https://skytrails.app/download

Let's explore birdwatching together! 🕊️🔭
"""

        let shareVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        if let popover = shareVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(shareVC, animated: true)
    }

    // MARK: - Logout Button

    private func setupLogoutButton() {

        logoutButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            logoutButton.topAnchor.constraint(equalTo: actionsStack.bottomAnchor, constant: 20),
            logoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logoutButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func styleLogoutButton() {

        logoutButton.configuration = .filled()
        logoutButton.configuration?.title = "Logout"
        logoutButton.configuration?.baseBackgroundColor = .systemRed
        logoutButton.configuration?.cornerStyle = .capsule
        logoutButton.configuration?.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
        logoutButton.configuration?.imagePadding = 8
    }

    // MARK: - Footer

    private func setupFooter() {

        aboutLabel.text = "SkyTrails"
        aboutLabel.textAlignment = .center
        aboutLabel.font = .preferredFont(forTextStyle: .footnote)
        aboutLabel.adjustsFontForContentSizeCategory = true
        aboutLabel.textColor = .secondaryLabel

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        versionLabel.text = "Version \(version)"
        versionLabel.textAlignment = .center
        versionLabel.font = .preferredFont(forTextStyle: .caption2)
        versionLabel.adjustsFontForContentSizeCategory = true
        versionLabel.textColor = .tertiaryLabel

        view.addSubview(aboutLabel)
        view.addSubview(versionLabel)
    }

    private func setupFooterConstraints() {

        aboutLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            aboutLabel.bottomAnchor.constraint(equalTo: versionLabel.topAnchor, constant: -2),
            aboutLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: - Helpers

    private func downsampleImage(_ data: Data) -> UIImage? {

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: avatarMaxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private func showMessage(_ message: String) {

        let alert = UIAlertController(title: "Profile",
                                      message: message,
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        present(alert, animated: true)
    }
}
